import 'dart:convert';
import 'dart:io';

import 'package:flutterflow_home_widget/flutterflow_home_widget.dart';
import 'package:flutterflow_home_widget/io.dart';
import 'package:test/test.dart';

void main() {
  final app = homeWidgetAppFromJson(
    jsonDecode(File('example/widgets.json').readAsStringSync())
        as Map<String, Object?>,
  );
  final stock = File('test/fixtures/flutter_create.pbxproj').readAsStringSync();

  group('Xcode project', () {
    final patched = addHomeWidgetTarget(stock, app);

    test('adds every fragment, once', () {
      for (final fragment in homeWidgetPbxprojFragments(app)) {
        expect(patched, contains(fragment));
      }
      expect(
        '/* $kHomeWidgetIosExtensionTarget */ = {'.allMatches(patched),
        hasLength(2), // the group and the target
      );
    });

    test('embeds the extension and makes the Runner depend on it', () {
      final runner = patched.substring(
        patched.indexOf('97C146ED1CF9000F007C117D /* Runner */ = {'),
      );
      final buildPhases = runner.substring(0, runner.indexOf('buildRules'));
      expect(buildPhases, contains(kHomeWidgetIosEmbedPhaseName));
      final dependencies = runner.substring(
        runner.indexOf('dependencies = ('),
        runner.indexOf(');', runner.indexOf('dependencies = (')),
      );
      expect(dependencies, contains('PBXTargetDependency'));
    });

    test('signs the Runner with its entitlements', () {
      expect(
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'.allMatches(
          patched,
        ),
        hasLength(3), // Debug, Release, Profile
      );
    });

    test('keeps braces and parentheses balanced', () {
      int count(String s, String c) => c.allMatches(s).length;
      expect(count(patched, '{'), count(patched, '}'));
      expect(count(patched, '('), count(patched, ')'));
    });

    test('a project that has the target stays as it is', () {
      expect(addHomeWidgetTarget(patched, app), patched);
    });

    test('a project not made by flutter create is refused', () {
      expect(
        () => addHomeWidgetTarget('// !\$*UTF8*\$!\n{}', app),
        throwsA(isA<HomeWidgetProjectException>()),
      );
    });
  });

  group('Runner plists', () {
    test('Info.plist gets the keychain group once', () {
      final plist = File(
        'test/fixtures/flutter_create_Info.plist',
      ).readAsStringSync();
      final patched = addHomeWidgetInfoPlistEntries(plist, app);
      expect(
        patched,
        contains(
          '<key>$kHomeWidgetKeychainGroupInfoPlistKey</key>\n'
          '    <string>\$(AppIdentifierPrefix)io.flutterflow.example.demo.'
          '$kHomeWidgetKeychainGroupSuffix</string>\n</dict>',
        ),
      );
      expect(addHomeWidgetInfoPlistEntries(patched, app), patched);
    });

    test('entitlements: created, or merged into an existing list', () {
      final created = homeWidgetRunnerEntitlements(null, app);
      expect(created, contains(app.appKeychainGroup));
      expect(created, contains(app.keychainGroup));
      const existing = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>keychain-access-groups</key>
	<array>
		<string>\$(AppIdentifierPrefix)io.flutterflow.example.demo</string>
	</array>
</dict>
</plist>
''';
      final merged = homeWidgetRunnerEntitlements(existing, app);
      expect(
        merged,
        contains(
          '\t\t<string>\$(AppIdentifierPrefix)io.flutterflow.example.demo</string>\n'
          '\t\t<string>${app.keychainGroup}</string>\n'
          '\t</array>',
        ),
      );
      expect(homeWidgetRunnerEntitlements(merged, app), merged);
    });
  });

  test('apply writes everything into a flutter create app, once', () {
    final dir = Directory.systemTemp.createTempSync('home_widget_apply');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/pubspec.yaml').writeAsStringSync(
      'name: demo\n\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );
    File('${dir.path}/ios/Runner.xcodeproj/project.pbxproj')
      ..createSync(recursive: true)
      ..writeAsStringSync(stock);
    File('${dir.path}/ios/Runner/Info.plist')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        File('test/fixtures/flutter_create_Info.plist').readAsStringSync(),
      );
    final written = applyHomeWidgets(dir.path, app);
    expect(
      written,
      containsAll([
        'pubspec.yaml',
        'ios/Runner.xcodeproj/project.pbxproj',
        'ios/Runner/Info.plist',
        'ios/Runner/Runner.entitlements',
        'ios/HomeWidget/HomeWidgetBundle.swift',
      ]),
    );
    expect(
      File('${dir.path}/pubspec.yaml').readAsStringSync(),
      contains('  ff_home_widget:\n    path: packages/ff_home_widget\n'),
    );
    expect(applyHomeWidgets(dir.path, app), isEmpty);
  });
}
