import 'dart:convert';
import 'dart:io';

import 'package:flutterflow_live_activity/flutterflow_live_activity.dart';
import 'package:flutterflow_live_activity/io.dart';
import 'package:test/test.dart';

import 'test_specs.dart';

final _pbxproj =
    File('test/fixtures/flutter_create.pbxproj').readAsStringSync();
final _infoPlist =
    File('test/fixtures/flutter_create_Info.plist').readAsStringSync();

/// The example: a Custom card with an Image value, and a fixed template.
final _example = liveActivityAppFromJson(
  jsonDecode(File('example/live_activities.json').readAsStringSync())
      as Map<String, Object?>,
);

/// An app of one fixed template: no Custom card, no Image value.
final _fixedOnly = appWith([fixedCard(LiveActivityTemplate.progress)]);

/// A Custom card without an Image value.
final _noImages = appWith([
  rideCard(
    values: [
      for (final value in rideValues)
        if (value.type != LiveActivityValueType.image) value,
    ],
    surfaces: {
      LiveActivitySurface.lockScreen: expandedLayout(),
      LiveActivitySurface.islandExpanded: expandedLayout(),
    },
  ),
]);

/// The fixture, with the Runner's bundle id (and the test target's) [id].
String _pbxprojOf(String id) =>
    _pbxproj.replaceAll('io.flutterflow.example.stock', id);

const _target = '/* $kLiveActivityIosExtensionTarget */ = {';
const _signRunner = 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;';

void main() {
  group('addLiveActivityTarget', () {
    test('adds every fragment once, and nothing on a second run', () {
      for (final app in [_example, _fixedOnly, _noImages]) {
        final once = addLiveActivityTarget(_pbxproj, app);
        for (final fragment in liveActivityPbxprojFragments(app)) {
          expect(once, contains(fragment));
        }
        // Its group and its target.
        expect(count(once, _target), 2);
        expect(
          once.length,
          _pbxproj.length +
              liveActivityPbxprojFragments(app).join().length +
              // The newline after the whole section of build files.
              1 +
              (app.hasImageValues ? 3 * '\t\t\t\t$_signRunner\n'.length : 0),
        );
        expect(addLiveActivityTarget(once, app), once);
      }
    });

    test('signs the Runner with entitlements only for an Image value', () {
      final withImages = addLiveActivityTarget(_pbxproj, _example);
      // Debug, Release and Profile.
      expect(count(withImages, _signRunner), 3);
      expect(
        addLiveActivityTarget(_pbxproj, _noImages),
        isNot(contains(_signRunner)),
      );
    });

    test('the extension signs with the Runner\'s team, per configuration', () {
      // A team for the Runner's Debug configuration only.
      final debug = _pbxproj.indexOf(
        '/* Debug */ = {\n\t\t\tisa = '
        'XCBuildConfiguration;\n\t\t\tbaseConfigurationReference = '
        '9740EEB21CF90195004384FC',
      );
      expect(debug, greaterThan(0));
      final at = _pbxproj.indexOf(
        '\t\t\t\tINFOPLIST_FILE = Runner/Info.plist;\n',
        debug,
      );
      final withTeam =
          '${_pbxproj.substring(0, at)}\t\t\t\tDEVELOPMENT_TEAM = AB12CD34EF;\n'
          '${_pbxproj.substring(at)}';
      final added = addLiveActivityTarget(withTeam, _example);
      final configuration = RegExp(
        r'/\* (\w+) \*/ = \{\n\t\t\tisa = XCBuildConfiguration;(.*?)\n\t\t\};',
        dotAll: true,
      );
      final teams = {
        for (final match in configuration.allMatches(added))
          if (match[2]!.contains('INFOPLIST_FILE = LiveActivity/Info.plist;'))
            match[1]!: match[2]!.contains('DEVELOPMENT_TEAM = AB12CD34EF;'),
      };
      expect(teams, {'Debug': true, 'Release': false, 'Profile': false});
    });

    test('a target added for other files has to be taken out first', () {
      final withCustom = addLiveActivityTarget(_pbxproj, _example);
      expect(
        () => addLiveActivityTarget(withCustom, _fixedOnly),
        throwsA(
          isA<LiveActivityProjectException>().having(
            (e) => e.message,
            'message',
            contains('Remove the LiveActivity target in Xcode'),
          ),
        ),
      );
      final withoutImages = addLiveActivityTarget(_pbxproj, _noImages);
      expect(
        () => addLiveActivityTarget(withoutImages, _example),
        throwsA(isA<LiveActivityProjectException>()),
      );
    });

    test('says what it cannot find', () {
      expect(
        () => addLiveActivityTarget(
          _pbxproj.replaceAll('/* Begin PBXGroup section */', ''),
          _example,
        ),
        throwsA(
          isA<LiveActivityProjectException>().having(
            (e) => e.message,
            'message',
            contains('Is it a flutter create project?'),
          ),
        ),
      );
    });
  });

  group('Info.plist', () {
    test('adds the entries once', () {
      final once = addLiveActivityInfoPlistEntries(_infoPlist, _example);
      expect(count(once, '<key>NSSupportsLiveActivities</key>'), 1);
      expect(
        count(once, '<key>$kLiveActivityKeychainGroupInfoPlistKey</key>'),
        1,
      );
      expect(once, contains(_example.keychainGroup));
      expect(once, endsWith('</dict>\n</plist>\n'));
      expect(addLiveActivityInfoPlistEntries(once, _example), once);
    });
  });

  group('Runner.entitlements', () {
    test('a new file has both keychain groups, the app\'s first', () {
      final text = liveActivityRunnerEntitlements(null, _example);
      expect(
        text.indexOf(_example.appKeychainGroup),
        lessThan(text.indexOf(_example.keychainGroup)),
      );
      expect(liveActivityRunnerEntitlements(text, _example), text);
    });

    test('an existing file keeps what it has', () {
      const own = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>development</string>
</dict>
</plist>
''';
      final added = liveActivityRunnerEntitlements(own, _example);
      expect(added, contains('<key>aps-environment</key>'));
      expect(count(added, '<key>keychain-access-groups</key>'), 1);
      expect(liveActivityRunnerEntitlements(added, _example), added);

      final group = '''
<plist version="1.0">
<dict>
	<key>keychain-access-groups</key>
	<array>
		<string>\$(AppIdentifierPrefix)com.example.other</string>
	</array>
</dict>
</plist>
''';
      final merged = liveActivityRunnerEntitlements(group, _example);
      expect(count(merged, '<string>'), 3);
      expect(merged, contains('com.example.other'));
      expect(liveActivityRunnerEntitlements(merged, _example), merged);
    });
  });

  group('applyLiveActivities', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('la_apply_');
      File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: courier
environment:
  sdk: ^3.7.0

dependencies:
  flutter:
    sdk: flutter
''');
      File('${dir.path}/ios/Runner.xcodeproj/project.pbxproj')
        ..createSync(recursive: true)
        ..writeAsStringSync(_pbxprojOf(_example.iosBundleId));
      File('${dir.path}/ios/Runner/Info.plist')
        ..createSync(recursive: true)
        ..writeAsStringSync(_infoPlist);
    });

    void setRunnerProject(String pbxproj) => File(
      '${dir.path}/ios/Runner.xcodeproj/project.pbxproj',
    ).writeAsStringSync(pbxproj);

    tearDown(() => dir.deleteSync(recursive: true));

    test('writes the app\'s files once; a second run changes nothing', () {
      final written = applyLiveActivities(dir.path, _example);
      expect(
        written,
        containsAll([
          'pubspec.yaml',
          'ios/Runner.xcodeproj/project.pbxproj',
          'ios/Runner/Info.plist',
          'ios/Runner/Runner.entitlements',
          kLiveActivityTypedApiPath,
          ...generateLiveActivityFiles(_example).keys,
        ]),
      );
      final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        contains(
          'dependencies:\n'
          '  ff_live_activity:\n'
          '    path: packages/ff_live_activity\n'
          '  flutter:\n',
        ),
      );
      expect(applyLiveActivities(dir.path, _example), isEmpty);
    });

    test('an app without an Image value has no entitlements', () {
      setRunnerProject(_pbxprojOf(_noImages.iosBundleId));
      applyLiveActivities(dir.path, _noImages);
      expect(
        File('${dir.path}/ios/Runner/Runner.entitlements').existsSync(),
        isFalse,
      );
    });

    test('without ios/, only the Dart and Android files', () {
      Directory('${dir.path}/ios').deleteSync(recursive: true);
      final written = applyLiveActivities(dir.path, _example);
      expect(written.where((path) => path.startsWith('ios/Runner/')), isEmpty);
      expect(written, contains('pubspec.yaml'));
    });

    test('a project that cannot take the extension is left as it was', () {
      List<String> files() => [
        for (final entity in dir.listSync(recursive: true))
          if (entity is File) '${entity.path}:${entity.readAsStringSync()}',
      ]..sort();

      File('${dir.path}/pubspec.yaml').deleteSync();
      var before = files();
      expect(
        () => applyLiveActivities(dir.path, _example),
        throwsA(isA<LiveActivityProjectException>()),
      );
      expect(files(), before);

      // A target added for a spec without Image values.
      File('${dir.path}/pubspec.yaml').writeAsStringSync('dependencies:\n');
      setRunnerProject(_pbxprojOf(_noImages.iosBundleId));
      applyLiveActivities(dir.path, _noImages);
      before = files();
      expect(
        () => applyLiveActivities(dir.path, _example),
        throwsA(isA<LiveActivityProjectException>()),
      );
      expect(files(), before);
    });

    group('the Runner\'s bundle id', () {
      String files() => [
        for (final entity in dir.listSync(recursive: true))
          if (entity is File) '${entity.path}:${entity.readAsStringSync()}',
      ].join('\n');

      void setRunnerProject(String pbxproj) => File(
        '${dir.path}/ios/Runner.xcodeproj/project.pbxproj',
      ).writeAsStringSync(pbxproj);

      test('an id that matches is applied, with no warning', () {
        final warnings = <String>[];
        applyLiveActivities(dir.path, _example, onWarning: warnings.add);
        expect(warnings, isEmpty);
      });

      test('an id nested under the Runner\'s is applied without images', () {
        setRunnerProject(_pbxprojOf('com.example'));
        expect(
          applyLiveActivities(dir.path, _noImages, onWarning: fail),
          isNotEmpty,
        );
      });

      test('a mismatch refuses, naming both ids, and writes nothing', () {
        setRunnerProject(_pbxprojOf('com.other.app'));
        final before = files();
        expect(
          () => applyLiveActivities(dir.path, _example),
          throwsA(
            isA<LiveActivityProjectException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('iosBundleId "${_example.iosBundleId}"'),
                contains('"com.other.app"'),
                contains('in Profile'),
              ),
            ),
          ),
        );
        expect(files(), before);
      });

      test('an id that only shares a prefix with the Runner\'s refuses', () {
        setRunnerProject(_pbxprojOf('${_noImages.iosBundleId}x'));
        expect(
          () => applyLiveActivities(dir.path, _noImages),
          throwsA(isA<LiveActivityProjectException>()),
        );
      });

      test('one configuration that does not match refuses, and says which', () {
        // Release keeps the example's id; Debug and Profile get another.
        var swapped = 0;
        final mixed = _pbxprojOf(_example.iosBundleId).replaceAllMapped(
          RegExp(
            r'(/\* (Debug|Profile) \*/ = \{\n\t\t\tisa = XCBuildConfiguration;'
            r'(?:(?!\n\t\t\};).)*?PRODUCT_BUNDLE_IDENTIFIER = )'
            '${RegExp.escape(_example.iosBundleId)};',
            dotAll: true,
          ),
          (m) {
            swapped++;
            return '${m[1]}com.other.app;';
          },
        );
        expect(swapped, greaterThan(0));
        setRunnerProject(mixed);
        final before = files();
        expect(
          () => applyLiveActivities(dir.path, _example),
          throwsA(
            isA<LiveActivityProjectException>().having(
              (e) => e.message,
              'message',
              contains('com.other.app'),
            ),
          ),
        );
        expect(files(), before);
      });

      test('an id from a build setting warns and continues', () {
        setRunnerProject(
          _pbxproj.replaceAll(
            'PRODUCT_BUNDLE_IDENTIFIER = io.flutterflow.example.stock;',
            r'PRODUCT_BUNDLE_IDENTIFIER = "$(APP_BUNDLE_ID)";',
          ),
        );
        final warnings = <String>[];
        final written = applyLiveActivities(
          dir.path,
          _example,
          onWarning: warnings.add,
        );
        expect(written, isNotEmpty);
        expect(warnings, isNotEmpty);
        expect(warnings.first, contains(r'$(APP_BUNDLE_ID)'));
      });
    });
  });
}
