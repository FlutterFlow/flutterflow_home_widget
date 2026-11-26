// The Dart half of the generated `ff_live_activity` plugin package: its
// pubspec and its library.
import 'package:flutterflow_live_activity/flutterflow_live_activity.dart';
import 'package:test/test.dart';

import 'test_specs.dart';

void main() {
  final files = liveActivityDartPackageFiles(
    appWith([fixedCard(LiveActivityTemplate.etaTimer)]),
  );

  test('the package is a pubspec and one library, under the contract path', () {
    expect(files.keys, [
      'packages/ff_live_activity/pubspec.yaml',
      'packages/ff_live_activity/lib/ff_live_activity.dart',
    ]);
    expect(
      files.keys.every((p) => p.startsWith('$kLiveActivityPluginPackagePath/')),
      isTrue,
    );
  });

  test('the pubspec declares the plugin class of both platforms', () {
    final pubspec = files[kLiveActivityPluginPubspecPath]!;
    expect(pubspec, contains('name: $kLiveActivityPluginPackage\n'));
    expect(pubspec, contains('publish_to: none\n'));
    expect(
      pubspec,
      contains(
        '    platforms:\n'
        '      ios:\n'
        '        pluginClass: $kLiveActivityPluginClass\n'
        '      android:\n'
        '        package: $kLiveActivityAndroidPackage\n'
        '        pluginClass: $kLiveActivityPluginClass\n',
      ),
    );
  });

  group('the library', () {
    final library = files[kLiveActivityPluginDartPath]!;

    test('declares FFLiveActivity over the contract channel', () {
      expect(library, contains('class FFLiveActivity {'));
      expect(
        library,
        contains("MethodChannel(\n    'flutterflow/live_activity',"),
      );
      for (final signature in [
        'static Future<bool> isSupported()',
        'static Future<bool> start({',
        'static Future<bool> update({',
        'static Future<void> end({',
        'static String? encodeDouble(num? value)',
        'static String? encodeInt(num? value)',
        'static String? encodeDateTime(DateTime? value)',
      ]) {
        expect(library, contains(signature), reason: signature);
      }
    });

    test('invokes every contract method and no other', () {
      final invoked =
          RegExp(
            r"_invoke<\w+>\('(\w+)'",
          ).allMatches(library).map((m) => m[1]).toList();
      expect(invoked, kLiveActivityMethods);
    });

    test('sends exactly the contract argument keys of each method', () {
      // The body of a method runs up to the next doc comment.
      for (final method in [
        kLiveActivityMethodStart,
        kLiveActivityMethodUpdate,
        kLiveActivityMethodEnd,
      ]) {
        final start = library.indexOf(
          '_invoke<',
          library.indexOf(' $method({'),
        );
        final body = library.substring(start, library.indexOf('///', start));
        final keys =
            RegExp(r"'(\w+)':").allMatches(body).map((m) => m[1]).toList();
        expect(keys, kLiveActivityMethodArguments[method], reason: method);
      }
    });

    test('names its parameters after the contract argument keys', () {
      for (final key in kLiveActivityMethodArguments.values.expand((k) => k)) {
        expect(
          library,
          matches(RegExp('(String\\??|Map<String, String\\?>) $key[, ]')),
          reason: key,
        );
      }
    });

    test('never reaches the channel off iOS and Android, and never throws', () {
      expect(library, isNot(contains('dart:io')));
      expect(library, contains('!kIsWeb &&'));
      expect(library, contains('defaultTargetPlatform == TargetPlatform.iOS'));
      expect(
        library,
        contains('defaultTargetPlatform == TargetPlatform.android'),
      );
      // One call site of the channel, guarded and inside a catch-all.
      expect('_channel.invokeMethod'.allMatches(library), hasLength(1));
      final invoke = library.substring(
        library.indexOf('static Future<T?> _invoke'),
      );
      expect(
        invoke.indexOf('if (!_hasNativeSide)'),
        lessThan(invoke.indexOf('_channel.invokeMethod')),
      );
      expect(invoke, contains('} catch (e) {'));
      expect(invoke, contains('return null;'));
    });

    test('has no unresolved template text', () {
      expect(library, isNot(contains(r'$k')));
      expect(
        library,
        contains(r"debugPrint('FFLiveActivity.$method failed: $e');"),
      );
    });

    test('does not depend on the fixed templates the app uses', () {
      expect(
        liveActivityDartPackageFiles(
          appWith([fixedCard(LiveActivityTemplate.score)]),
        ),
        files,
      );
      expect(library, liveActivityPluginDartLibrary());
    });

    test('a Custom card adds the pictures, defaults and encoders', () {
      final custom = liveActivityPluginDartLibrary(custom: true);
      expect(custom, startsWith(library.substring(0, 40)));
      for (final part in [
        'static String? $kLiveActivityEncodeBool(bool? value)',
        'static String? $kLiveActivityEncodeColor(',
        "'$kLiveActivityArgImages':",
      ]) {
        expect(custom, contains(part), reason: part);
        expect(library, isNot(contains(part)), reason: part);
      }
    });
  });
}
