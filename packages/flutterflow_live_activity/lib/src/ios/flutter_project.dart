/// Adds the Live Activity extension to the iOS project of an app made by
/// `flutter create`: the target in `project.pbxproj`, the entries of the
/// Runner's Info.plist and, when a card has an Image value, the keychain
/// group in the Runner's entitlements.
library;

import 'package:flutterflow_live_activity/src/contract.dart';
import 'package:flutterflow_live_activity/src/generate.dart';
import 'package:flutterflow_live_activity/src/ios/image_store.dart';
import 'package:flutterflow_live_activity/src/ios/pbxproj_fragments.dart';
import 'package:flutterflow_live_activity/src/spec.dart';

/// Thrown when a file does not look like what `flutter create` writes, so
/// the Live Activity extension cannot be added to it safely.
class LiveActivityProjectException implements Exception {
  LiveActivityProjectException(this.message);

  final String message;

  @override
  String toString() => 'LiveActivityProjectException: $message';
}

// Object ids every `flutter create` project shares.
const _runnerGroup = '97C146F01CF9000F007C117D /* Runner */,';
const _runnerApp = '97C146EE1CF9000F007C117D /* Runner.app */,';
const _runnerTarget = '97C146ED1CF9000F007C117D /* Runner */';
const _embedFrameworks = '9705A1C41CF9048500538489 /* Embed Frameworks */,';

/// Where the Runner's entitlements live, relative to `ios/`.
const kLiveActivityRunnerEntitlementsPath = 'Runner/Runner.entitlements';

/// [pbxproj] (an `ios/Runner.xcodeproj/project.pbxproj` made by `flutter
/// create`, alone or with other extensions added the same way) with the
/// Live Activity extension target of [app] added. The extension signs with
/// the Runner's development team, configuration by configuration. When a
/// card has an Image value, the Runner is signed with
/// `Runner/Runner.entitlements`.
///
/// A project that already has the target is returned as it is, unless the
/// target was added for a spec with other files (a Custom card or an Image
/// value added or removed since): that throws, as the target has to be
/// taken out by hand first.
String addLiveActivityTarget(String pbxproj, LiveActivityApp app) {
  const target = kLiveActivityIosExtensionTarget;
  if (pbxproj.contains('/* $target */ = {')) {
    for (final (file, needed) in [
      (kLiveActivityIosCardsSwiftFile, app.hasCustomCards),
      (kLiveActivityIosEntitlementsFile, app.hasImageValues),
    ]) {
      if (pbxproj.contains('/* $file */ = {isa = PBXFileReference;') !=
          needed) {
        throw LiveActivityProjectException(
          'project.pbxproj has a $target target ${needed ? 'without' : 'with'} '
          '$file, which this spec ${needed ? 'needs' : 'does not have'}. '
          'Remove the $target target in Xcode, then apply again.',
        );
      }
    }
    return pbxproj;
  }
  final fragments = liveActivityPbxprojFragments(app);
  fragments[16] = _withDevelopmentTeams(
    fragments[16],
    _runnerDevelopmentTeams(pbxproj),
  );
  var text = pbxproj;

  String insertAfter(String text, String anchor, String fragment, int slot) {
    final at = text.indexOf(anchor);
    if (at < 0) {
      throw LiveActivityProjectException(
        'project.pbxproj has no "$anchor", where '
        '${kLiveActivityPbxprojSlots[slot]} goes. Is it a flutter create '
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
  final dependencies =
      runner < 0 ? -1 : text.indexOf('dependencies = (', runner);
  if (dependencies < 0) {
    throw LiveActivityProjectException(
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
  return app.hasImageValues ? _signRunnerWithEntitlements(text) : text;
}

/// The `DEVELOPMENT_TEAM` of each of the Runner's build configurations that
/// sets one, by configuration name.
Map<String, String> _runnerDevelopmentTeams(String pbxproj) {
  final configuration = RegExp(
    r'^\t\t[0-9A-F]{24} /\* (\w+) \*/ = \{\n\t\t\tisa = XCBuildConfiguration;(.*?)\n\t\t\};',
    multiLine: true,
    dotAll: true,
  );
  final team = RegExp(r'^\s*DEVELOPMENT_TEAM = "?([^";]+)"?;', multiLine: true);
  return {
    for (final match in configuration.allMatches(pbxproj))
      if (match[2]!.contains('INFOPLIST_FILE = Runner/Info.plist;'))
        if (team.firstMatch(match[2]!)?[1] case final id?) match[1]!: id,
  };
}

/// [configurations] (fragment 16: the extension's build configurations)
/// with the Runner's development team of the same configuration, so the
/// extension signs as the app does.
String _withDevelopmentTeams(String configurations, Map<String, String> teams) {
  if (teams.isEmpty) {
    return configurations;
  }
  final block = RegExp(
    r'/\* (\w+) \*/ = \{\n\t\t\tisa = XCBuildConfiguration;.*?\n\t\t\};',
    dotAll: true,
  );
  return configurations.replaceAllMapped(block, (match) {
    final team = teams[match[1]];
    return team == null
        ? match[0]!
        : match[0]!.replaceFirst(
          '\t\t\t\tCODE_SIGN_STYLE = Automatic;\n',
          '\t\t\t\tCODE_SIGN_STYLE = Automatic;\n'
              '\t\t\t\tDEVELOPMENT_TEAM = $team;\n',
        );
  });
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
      '${indent}CODE_SIGN_ENTITLEMENTS = $kLiveActivityRunnerEntitlementsPath;',
    );
  }
  return out.join('\n');
}

/// [infoPlist] (the Runner's) with the entries [app] needs
/// ([liveActivityRunnerInfoPlistEntries]) that it does not have yet.
String addLiveActivityInfoPlistEntries(String infoPlist, LiveActivityApp app) {
  final entries = StringBuffer();
  if (!infoPlist.contains('<key>NSSupportsLiveActivities</key>')) {
    entries.write(kLiveActivityRunnerInfoPlistEntries);
  }
  if (!infoPlist.contains(
    '<key>$kLiveActivityKeychainGroupInfoPlistKey</key>',
  )) {
    entries.write(liveActivityKeychainGroupInfoPlistEntry(app));
  }
  return entries.isEmpty
      ? infoPlist
      : _beforeLastDict(infoPlist, entries.toString(), 'Info.plist');
}

/// The Runner's entitlements with the keychain groups of [app] (its own,
/// then the one it shares with the extension, where the cards' pictures
/// are): [existing] with them added, or a new file when [existing] is
/// null. Only an app with an Image value needs them.
String liveActivityRunnerEntitlements(String? existing, LiveActivityApp app) {
  final entries = '''

	<key>keychain-access-groups</key>
	<array>
		<string>${app.appKeychainGroup}</string>
		<string>${app.keychainGroup}</string>
	</array>''';
  if (existing == null) {
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>$entries
</dict>
</plist>
''';
  }
  const key = '<key>keychain-access-groups</key>';
  final at = existing.indexOf(key);
  if (at < 0) {
    return _beforeLastDict(
      existing,
      '${entries.substring(1)}\n',
      'Runner.entitlements',
    );
  }
  // Add the groups the list lacks, the app's own first.
  final arrayEnd = existing.indexOf('</array>', at);
  if (arrayEnd < 0) {
    throw LiveActivityProjectException(
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
    throw LiveActivityProjectException('$name has no top-level <dict>.');
  }
  return plist.substring(0, at) + entries + plist.substring(at);
}
