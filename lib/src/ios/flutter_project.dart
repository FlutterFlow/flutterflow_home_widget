/// Adds the widget extension to the iOS project of an app made by
/// `flutter create`: the target in `project.pbxproj`, the keychain group in
/// the Runner's Info.plist and entitlements.
library;

import 'package:flutterflow_home_widget/src/contract.dart';
import 'package:flutterflow_home_widget/src/generate.dart';
import 'package:flutterflow_home_widget/src/ios/pbxproj_fragments.dart';
import 'package:flutterflow_home_widget/src/spec.dart';

/// Thrown when a file does not look like what `flutter create` writes, so
/// the widget extension cannot be added to it safely.
class HomeWidgetProjectException implements Exception {
  HomeWidgetProjectException(this.message);

  final String message;

  @override
  String toString() => 'HomeWidgetProjectException: $message';
}

// Object ids every `flutter create` project shares.
const _runnerGroup = '97C146F01CF9000F007C117D /* Runner */,';
const _runnerApp = '97C146EE1CF9000F007C117D /* Runner.app */,';
const _runnerTarget = '97C146ED1CF9000F007C117D /* Runner */';
const _embedFrameworks = '9705A1C41CF9048500538489 /* Embed Frameworks */,';

/// Where the Runner's entitlements live, relative to `ios/`.
const kHomeWidgetRunnerEntitlementsPath = 'Runner/Runner.entitlements';

/// [pbxproj] (an `ios/Runner.xcodeproj/project.pbxproj` made by `flutter
/// create`) with the widget extension target of [app] added, and the Runner
/// signed with `Runner/Runner.entitlements`. A project that already has the
/// target is returned as it is.
String addHomeWidgetTarget(String pbxproj, HomeWidgetApp app) {
  // The extension signs with the Runner's team, configuration by
  // configuration: an app whose team is set on its target only would
  // otherwise build an extension nobody can sign.
  final fragments = homeWidgetPbxprojFragments(
    app,
    developmentTeams: runnerDevelopmentTeams(pbxproj),
  );
  if (pbxproj.contains('/* $kHomeWidgetIosExtensionTarget */ = {')) {
    return pbxproj;
  }
  var text = pbxproj;

  String insertAfter(String text, String anchor, String fragment, int slot) {
    final at = text.indexOf(anchor);
    if (at < 0) {
      throw HomeWidgetProjectException(
        'project.pbxproj has no "$anchor", where '
        '${kHomeWidgetPbxprojSlots[slot]} goes. Is it a flutter create '
        'project?',
      );
    }
    final end = at + anchor.length;
    return text.substring(0, end) + fragment + text.substring(end);
  }

  String sectionStart(String isa) => '/* Begin $isa section */';

  // Whole lines (0, 3) go after their section's first line; a whole section
  // (1) after the build files. Every other fragment starts with a newline.
  text = insertAfter(
    text,
    '${sectionStart('PBXBuildFile')}\n',
    fragments[0],
    0,
  );
  text = insertAfter(
    text,
    '/* End PBXBuildFile section */\n',
    '${fragments[1]}\n',
    1,
  );
  text = insertAfter(
    text,
    sectionStart('PBXCopyFilesBuildPhase'),
    fragments[2],
    2,
  );
  text = insertAfter(
    text,
    '${sectionStart('PBXFileReference')}\n',
    fragments[3],
    3,
  );
  text = insertAfter(
    text,
    sectionStart('PBXFrameworksBuildPhase'),
    fragments[4],
    4,
  );
  text = insertAfter(text, sectionStart('PBXGroup'), fragments[5], 5);
  text = insertAfter(text, _runnerGroup, fragments[6], 6);
  text = insertAfter(text, _runnerApp, fragments[7], 7);
  text = insertAfter(text, sectionStart('PBXNativeTarget'), fragments[8], 8);
  text = insertAfter(text, _embedFrameworks, fragments[9], 9);
  // The Runner's own dependency list, not another target's.
  final runner = text.indexOf('$_runnerTarget = {');
  final dependencies = runner < 0
      ? -1
      : text.indexOf('dependencies = (', runner);
  if (dependencies < 0) {
    throw HomeWidgetProjectException(
      'project.pbxproj has no Runner target with dependencies.',
    );
  }
  final afterDependencies = dependencies + 'dependencies = ('.length;
  text =
      text.substring(0, afterDependencies) +
      fragments[10] +
      text.substring(afterDependencies);
  text = insertAfter(text, 'TargetAttributes = {', fragments[11], 11);
  text = insertAfter(text, '$_runnerTarget,', fragments[12], 12);
  text = insertAfter(
    text,
    sectionStart('PBXResourcesBuildPhase'),
    fragments[13],
    13,
  );
  text = insertAfter(
    text,
    sectionStart('PBXSourcesBuildPhase'),
    fragments[14],
    14,
  );
  text = insertAfter(
    text,
    '/* End PBXSourcesBuildPhase section */',
    fragments[15],
    15,
  );
  text = insertAfter(
    text,
    sectionStart('XCBuildConfiguration'),
    fragments[16],
    16,
  );
  text = insertAfter(
    text,
    sectionStart('XCConfigurationList'),
    fragments[17],
    17,
  );
  return _signRunnerWithEntitlements(text);
}

/// The `DEVELOPMENT_TEAM` of each of the Runner's build configurations that
/// sets one, by configuration name.
Map<String, String> runnerDevelopmentTeams(String pbxproj) {
  final configuration = RegExp(
    r'^\t\t[0-9A-F]{24} /\* (\w+) \*/ = \{\n\t\t\tisa = XCBuildConfiguration;(.*?)\n\t\t\};',
    multiLine: true,
    dotAll: true,
  );
  final team = RegExp(r'^\s*DEVELOPMENT_TEAM = "?([^";]+)"?;', multiLine: true);
  return {
    for (final match in configuration.allMatches(pbxproj))
      if (match[2]!.contains('INFOPLIST_FILE = Runner/Info.plist;'))
        match[1]!: ?team.firstMatch(match[2]!)?[1],
  };
}

/// Adds `CODE_SIGN_ENTITLEMENTS` to each of the Runner's build
/// configurations that has none.
String _signRunnerWithEntitlements(String pbxproj) {
  const infoPlist = 'INFOPLIST_FILE = Runner/Info.plist;';
  final lines = pbxproj.split('\n');
  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    out.add(lines[i]);
    if (lines[i].trim() != infoPlist) {
      continue;
    }
    // The configuration's build settings, up to its closing brace.
    var close = i;
    while (close < lines.length && lines[close].trim() != '};') {
      close++;
    }
    var start = i;
    while (start > 0 && !lines[start].contains('buildSettings = {')) {
      start--;
    }
    final settings = lines.sublist(start, close);
    if (settings.any((l) => l.trim().startsWith('CODE_SIGN_ENTITLEMENTS'))) {
      continue;
    }
    final indent = lines[i].substring(0, lines[i].indexOf('INFOPLIST_FILE'));
    out.add(
      '${indent}CODE_SIGN_ENTITLEMENTS = $kHomeWidgetRunnerEntitlementsPath;',
    );
  }
  return out.join('\n');
}

/// [infoPlist] (the Runner's) with the keychain group entry of [app].
String addHomeWidgetInfoPlistEntries(String infoPlist, HomeWidgetApp app) {
  if (infoPlist.contains('<key>$kHomeWidgetKeychainGroupInfoPlistKey</key>')) {
    return infoPlist;
  }
  return _beforeLastDict(
    infoPlist,
    homeWidgetRunnerInfoPlistEntries(app),
    'Info.plist',
  );
}

/// The Runner's entitlements with the keychain groups of [app]: [existing]
/// with them added, or a new file when [existing] is null.
String homeWidgetRunnerEntitlements(String? existing, HomeWidgetApp app) {
  if (existing == null) {
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>${homeWidgetRunnerEntitlementEntries(app)}
</dict>
</plist>
''';
  }
  const key = '<key>keychain-access-groups</key>';
  final at = existing.indexOf(key);
  if (at < 0) {
    return _beforeLastDict(
      existing,
      '${homeWidgetRunnerEntitlementEntries(app).substring(1)}\n',
      'Runner.entitlements',
    );
  }
  // Add the groups the list lacks, the app's own first.
  final arrayEnd = existing.indexOf('</array>', at);
  if (arrayEnd < 0) {
    throw HomeWidgetProjectException(
      'Runner.entitlements has keychain-access-groups without an array.',
    );
  }
  final missing = [
    for (final group in [app.appKeychainGroup, app.keychainGroup])
      if (!existing.substring(at, arrayEnd).contains('<string>$group</string>'))
        '\t\t<string>$group</string>\n',
  ];
  final lineStart = existing.lastIndexOf('\n', arrayEnd) + 1;
  return existing.substring(0, lineStart) +
      missing.join() +
      existing.substring(lineStart);
}

String _beforeLastDict(String plist, String entries, String name) {
  final at = plist.lastIndexOf('</dict>');
  if (at < 0) {
    throw HomeWidgetProjectException('$name has no top-level <dict>.');
  }
  return plist.substring(0, at) + entries + plist.substring(at);
}
