import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutterflow_live_activity/flutterflow_live_activity.dart';
import 'package:flutterflow_live_activity/io.dart';
import 'package:test/test.dart';

final _pbxproj =
    File('test/fixtures/flutter_create.pbxproj').readAsStringSync();
final _infoPlist =
    File('test/fixtures/flutter_create_Info.plist').readAsStringSync();

Map<String, Object?> _exampleJson() =>
    jsonDecode(File('example/live_activities.json').readAsStringSync())
        as Map<String, Object?>;

LiveActivityApp _appOf(List<Map<String, Object?>> activities) {
  final json = _exampleJson()..['activities'] = activities;
  return liveActivityAppFromJson(json);
}

/// The example's Custom card, as a second one with a key and name of its own.
Map<String, Object?> _delivery({String? as}) {
  final card = Map<String, Object?>.of(
    (_exampleJson()['activities'] as List).first as Map<String, Object?>,
  );
  return as == null ? card : {...card, 'key': as, 'name': as};
}

Map<String, Object?> get _upload =>
    (_exampleJson()['activities'] as List).last as Map<String, Object?>;

/// A fixed card and a Custom card with Image values (the example).
final _both = _appOf([_upload, _delivery()]);

/// The same app without the Custom card.
final _fixedOnly = _appOf([_upload]);

/// Two Custom cards, and the same without the second.
final _twoCustom = _appOf([_delivery(), _delivery(as: 'pickup')]);
final _oneCustom = _appOf([_delivery()]);

final _bundleId = _both.iosBundleId;
const _cards = 'ios/LiveActivity/LiveActivityCards.swift';
const _entitlements = 'ios/LiveActivity/LiveActivity.entitlements';
const _pbxprojPath = 'ios/Runner.xcodeproj/project.pbxproj';

Set<String> _paths(LiveActivityApp app) => {
  ...generateLiveActivityFiles(app).keys,
  ...liveActivityTypedApiFiles(app).keys,
};

void main() {
  late Directory dir;
  late String root;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('la_manifest_');
    root = dir.path;
    File('$root/pubspec.yaml').writeAsStringSync('''
name: courier
environment:
  sdk: ^3.7.0

dependencies:
  flutter:
    sdk: flutter
''');
    File('$root/$_pbxprojPath')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        _pbxproj.replaceAll('io.flutterflow.example.stock', _bundleId),
      );
    File('$root/ios/Runner/Info.plist')
      ..createSync(recursive: true)
      ..writeAsStringSync(_infoPlist);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  bool exists(String path) => File('$root/$path').existsSync();

  String read(String path) => File('$root/$path').readAsStringSync();

  /// Every file under the app, with its content.
  Map<String, String> snapshot() => {
    for (final entity in dir.listSync(recursive: true))
      if (entity is File)
        entity.path.substring(root.length + 1): entity.readAsStringSync(),
  };

  Map<String, String> manifestFiles() =>
      ((jsonDecode(read(kLiveActivityManifestPath))
                  as Map<String, Object?>)['files']
              as Map<String, Object?>)
          .cast<String, String>();

  test('records every generated file with the hash of what it wrote', () {
    applyLiveActivities(root, _both);
    final files = manifestFiles();
    expect(files.keys.toSet(), _paths(_both));
    for (final MapEntry(:key, :value) in files.entries) {
      expect(sha256.convert(utf8.encode(read(key))).toString(), value);
    }
    // Files it only edits are not its own.
    expect(files, isNot(contains('pubspec.yaml')));
    expect(files, isNot(contains(_pbxprojPath)));
    expect(files, isNot(contains('ios/Runner/Info.plist')));
  });

  test(
    'removes what the spec no longer generates; a rerun changes nothing',
    () {
      applyLiveActivities(root, _both);
      final stale = _paths(_both).difference(_paths(_fixedOnly));
      expect(stale, contains(_cards));
      expect(stale, contains(_entitlements));
      expect(
        stale.where((p) => p.contains('hw_layout_la_delivery')),
        isNotEmpty,
      );
      for (final path in stale) {
        expect(exists(path), isTrue, reason: path);
      }

      final removed = <String>[];
      applyLiveActivities(
        root,
        _fixedOnly,
        onWarning: fail,
        onRemoved: removed.add,
      );

      expect(removed.toSet(), stale);
      for (final path in stale) {
        expect(exists(path), isFalse, reason: path);
      }
      for (final path in _paths(_fixedOnly)) {
        expect(exists(path), isTrue, reason: path);
      }
      expect(manifestFiles().keys.toSet(), _paths(_fixedOnly));
      // No references to the removed files in the Xcode project, and what is
      // left is what applying the smaller spec to a fresh project writes.
      final pbxproj = read(_pbxprojPath);
      expect(pbxproj, isNot(contains('LiveActivityCards.swift')));
      expect(pbxproj, isNot(contains('LiveActivity.entitlements')));
      expect(pbxproj, contains('LiveActivityBundle.swift'));
      // Apart from the Runner's own entitlements setting, which `apply` added
      // for the Image values but cannot tell from one that was there before.
      expect(
        pbxproj.replaceAll(
          '\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n',
          '',
        ),
        addLiveActivityTarget(
          _pbxproj.replaceAll('io.flutterflow.example.stock', _bundleId),
          _fixedOnly,
        ),
        reason: 'the project is as if the Custom card was never there',
      );
      // Folders left empty went with their files.
      expect(
        Directory(
          '$root/packages/ff_live_activity/android/src/main/res/layout',
        ).existsSync(),
        _paths(_fixedOnly).any((p) => p.contains('/res/layout/')),
      );

      final after = snapshot();
      expect(applyLiveActivities(root, _fixedOnly, onWarning: fail), isEmpty);
      expect(snapshot(), after);
    },
  );

  test('removing one of two Custom cards keeps the other\'s files and the '
      'shared ones', () {
    applyLiveActivities(root, _twoCustom);
    final stale = _paths(_twoCustom).difference(_paths(_oneCustom));
    expect(stale, isNotEmpty);
    expect(stale, isNot(contains(_cards)));
    expect(stale, isNot(contains(_entitlements)));

    final removed = <String>[];
    applyLiveActivities(
      root,
      _oneCustom,
      onWarning: fail,
      onRemoved: removed.add,
    );
    expect(removed.toSet(), stale);
    for (final path in _paths(_oneCustom)) {
      expect(exists(path), isTrue, reason: path);
    }
    expect(read(_pbxprojPath), contains('LiveActivityCards.swift'));
    expect(read(_pbxprojPath), contains('LiveActivity.entitlements'));
  });

  test('a file changed since it was generated stays, with a warning', () {
    applyLiveActivities(root, _both);
    final stale = _paths(_both).difference(_paths(_fixedOnly));
    File('$root/$_cards').writeAsStringSync('// my own card\n');
    final layout = stale.firstWhere((p) => p.contains('/res/layout/'));
    File('$root/$layout').writeAsStringSync('<!-- mine -->');

    final warnings = <String>[];
    final removed = <String>[];
    applyLiveActivities(
      root,
      _fixedOnly,
      onWarning: warnings.add,
      onRemoved: removed.add,
    );

    expect(read(_cards), '// my own card\n');
    expect(read(layout), '<!-- mine -->');
    expect(
      warnings,
      containsAll([
        allOf(contains(_cards), contains('changed since')),
        allOf(contains(layout), contains('changed since')),
      ]),
    );
    expect(removed, isNot(contains(_cards)));
    expect(removed, isNot(contains(layout)));
    // The ones it wrote and nobody touched are gone.
    expect(exists(_entitlements), isFalse);
    // The edited Swift file stays in the target; the entitlements go.
    expect(read(_pbxprojPath), contains('LiveActivityCards.swift'));
    expect(read(_pbxprojPath), isNot(contains('LiveActivity.entitlements')));

    // Reported again while it is there; nothing else changes.
    final again = snapshot();
    final warningsAgain = <String>[];
    applyLiveActivities(root, _fixedOnly, onWarning: warningsAgain.add);
    expect(warningsAgain, hasLength(2));
    expect(snapshot(), again);

    // Once it is deleted by hand, the next run takes it out of the target.
    File('$root/$_cards').deleteSync();
    File('$root/$layout').deleteSync();
    applyLiveActivities(root, _fixedOnly, onWarning: fail);
    expect(read(_pbxprojPath), isNot(contains('LiveActivityCards.swift')));
    expect(manifestFiles(), isNot(contains(_cards)));
  });

  test('an app applied without a manifest has nothing deleted', () {
    applyLiveActivities(root, _both);
    File('$root/$kLiveActivityManifestPath').deleteSync();
    final before = snapshot();

    // The same spec: only the manifest is written.
    final written = applyLiveActivities(root, _both, onWarning: fail);
    expect(written, [kLiveActivityManifestPath]);
    expect({...snapshot()}..remove(kLiveActivityManifestPath), before);

    // A smaller spec without a manifest: the Xcode target still has the
    // Custom card's file, so it is refused as before, and nothing changes.
    File('$root/$kLiveActivityManifestPath').deleteSync();
    final noManifest = snapshot();
    expect(
      () => applyLiveActivities(root, _fixedOnly),
      throwsA(isA<LiveActivityProjectException>()),
    );
    expect(snapshot(), noManifest);
    for (final path in _paths(_both)) {
      expect(exists(path), isTrue, reason: path);
    }
  });

  test('a manifest that cannot be read deletes nothing', () {
    applyLiveActivities(root, _twoCustom);
    File('$root/$kLiveActivityManifestPath').writeAsStringSync('{not json');
    final warnings = <String>[];
    applyLiveActivities(root, _oneCustom, onWarning: warnings.add);
    expect(warnings, [contains('cannot be read')]);
    for (final path in _paths(_twoCustom)) {
      expect(exists(path), isTrue, reason: path);
    }
    // It is rewritten for the spec just applied.
    expect(manifestFiles().keys.toSet(), _paths(_oneCustom));
  });

  test('a manifest path outside the generated folders is never deleted', () {
    applyLiveActivities(root, _both);
    final outside = File('${dir.parent.path}/la_outside_${dir.hashCode}.txt')
      ..writeAsStringSync('keep');
    addTearDown(outside.deleteSync);
    final keepHash = sha256.convert(utf8.encode('keep')).toString();
    final manifest = {
      'version': 1,
      'files': {
        ...manifestFiles(),
        '../${outside.uri.pathSegments.last}': keepHash,
        '/etc/hosts': 'x',
        'pubspec.yaml':
            sha256.convert(utf8.encode(read('pubspec.yaml'))).toString(),
      },
    };
    File(
      '$root/$kLiveActivityManifestPath',
    ).writeAsStringSync(jsonEncode(manifest));
    final warnings = <String>[];
    applyLiveActivities(root, _both, onWarning: warnings.add);
    expect(outside.existsSync(), isTrue);
    // Only the folders it generates into are ever deleted from: not the
    // pubspec it edits, not a path out of the app.
    expect(warnings.where((w) => w.contains('not a generated')), hasLength(3));
    expect(read('pubspec.yaml'), contains('ff_live_activity'));
  });

  test('a refused apply writes and deletes nothing', () {
    applyLiveActivities(root, _both);
    final before = snapshot();

    // Wrong bundle id.
    final wrongId = LiveActivityApp(
      iosBundleId: 'com.other.app',
      iosDeviceFamily: _fixedOnly.iosDeviceFamily,
      routes: _fixedOnly.routes,
      activities: _fixedOnly.activities,
    );
    expect(
      () => applyLiveActivities(root, wrongId),
      throwsA(isA<LiveActivityProjectException>()),
    );
    expect(snapshot(), before);

    // A project that cannot take it.
    File('$root/ios/Runner/Info.plist').writeAsStringSync('not a plist');
    final broken = snapshot();
    expect(
      () => applyLiveActivities(root, _fixedOnly),
      throwsA(isA<LiveActivityProjectException>()),
    );
    expect(snapshot(), broken);
    for (final path in _paths(_both)) {
      expect(exists(path), isTrue, reason: path);
    }
  });
}
