// The iOS files of an app with fixed templates only: the widget extension
// and the iOS side of the plugin package. Whether the Swift builds and draws
// correctly is a simulator gate, not this test; this pins what is generated,
// where, and that it follows the channel contract.
import 'dart:io';

import 'package:flutterflow_live_activity/flutterflow_live_activity.dart';
import 'package:test/test.dart';

import 'test_specs.dart';

final _fixedTemplates = [
  for (final template in LiveActivityTemplate.values)
    if (!template.isCustom) template,
];

void main() {
  const extension = 'ios/$kLiveActivityIosExtensionTarget';
  const plugin = '$kLiveActivityPluginPackagePath/ios';
  const sources =
      '$plugin/$kLiveActivityPluginPackage/Sources/$kLiveActivityPluginPackage';
  const attributesFile = '$kLiveActivityAttributesType.swift';

  final app = appWith([fixedCard(LiveActivityTemplate.etaTimer)]);
  final files = liveActivityIosFiles(app);
  final widget =
      files['$extension/${kLiveActivityIosExtensionTarget}Bundle.swift']!;
  final pluginSwift = files['$sources/$kLiveActivityPluginClass.swift']!;

  group('files', () {
    test('the extension target and the plugin iOS side, nothing else', () {
      expect(files.keys.toSet(), {
        '$extension/Info.plist',
        '$extension/${kLiveActivityIosExtensionTarget}Bundle.swift',
        '$extension/$attributesFile',
        '$plugin/$kLiveActivityPluginPackage.podspec',
        '$plugin/$kLiveActivityPluginPackage/Package.swift',
        '$sources/$kLiveActivityPluginClass.swift',
        '$sources/$attributesFile',
      });
    });

    test('the attributes struct is one text in both places', () {
      expect(files['$extension/$attributesFile'], liveActivityAttributesSwift);
      expect(files['$sources/$attributesFile'], liveActivityAttributesSwift);
    });

    test('do not depend on the fixed templates the app uses', () {
      expect(
        liveActivityIosFiles(
          appWith([
            fixedCard(LiveActivityTemplate.score),
            fixedCard(LiveActivityTemplate.progress, key: 'la_other'),
          ]),
        ),
        files,
      );
      expect(liveActivityIosFiles(appWith(const [])), files);
    });
  });

  group('plugin package manifests', () {
    test('podspec and Package.swift name the package and its sources', () {
      final podspec = files['$plugin/$kLiveActivityPluginPackage.podspec']!;
      expect(podspec, contains("s.name             = 'ff_live_activity'"));
      expect(
        podspec,
        contains("'ff_live_activity/Sources/ff_live_activity/**/*'"),
      );
      expect(podspec, contains("s.weak_frameworks  = 'ActivityKit'"));
      final package =
          files['$plugin/$kLiveActivityPluginPackage/Package.swift']!;
      expect(package, contains('name: "ff_live_activity"'));
      expect(package, contains('.library(name: "ff-live-activity"'));
    });

    test('the extension plist is a WidgetKit extension', () {
      final plist = files['$extension/Info.plist']!;
      expect(plist, kLiveActivityExtensionInfoPlist);
      expect(plist, contains('<string>com.apple.widgetkit-extension</string>'));
      expect(plist, contains(r'<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>'));
      expect(plist, isNot(contains(kLiveActivityKeychainGroupInfoPlistKey)));
    });
  });

  group('plugin', () {
    test('a started card outranks the running ones; updates keep the rank', () {
      // The Lock Screen shows one card of an app at a time, the highest
      // relevance (default 0, a tie keeps the older card).
      expect(
        pluginSwift,
        contains(RegExp(
          r'Activity\.request\((?:(?!pushType).)*relevanceScore: Date\(\)\.timeIntervalSince1970',
          dotAll: true,
        )),
      );
      expect(pluginSwift, isNot(contains('staleDate: nil)')));
      expect(
        'relevanceScore: activity.content.relevanceScore'
            .allMatches(pluginSwift),
        hasLength(2),
      );
    });

    test('registers the contract channel and class', () {
      expect(
        pluginSwift,
        contains('public class $kLiveActivityPluginClass: NSObject'),
      );
      expect(pluginSwift, contains('name: "$kLiveActivityChannelName"'));
    });

    test('handles every contract method', () {
      for (final method in kLiveActivityMethods) {
        expect(pluginSwift, contains('"$method"'), reason: method);
      }
    });

    test('reads every argument key iOS uses', () {
      final iosArguments =
          kLiveActivityMethodArguments.values.expand((keys) => keys).toSet()
            ..remove(kLiveActivityArgAndroidChannelName);
      for (final key in iosArguments) {
        expect(pluginSwift, contains('args["$key"]'), reason: key);
      }
      expect(pluginSwift, isNot(contains(kLiveActivityArgAndroidChannelName)));
    });

    test('answers false below the minimum iOS and still builds for 15', () {
      expect(
        pluginSwift,
        contains('if #available(iOS $kLiveActivityMinIosVersion, *) {'),
      );
      expect(
        pluginSwift,
        contains(
          'case "$kLiveActivityMethodIsSupported", '
          '"$kLiveActivityMethodStart", "$kLiveActivityMethodUpdate": '
          'result(false)',
        ),
      );
      expect(
        pluginSwift,
        contains('case "$kLiveActivityMethodEnd": result(nil)'),
      );
      // ActivityKit only ever appears behind the availability attribute.
      expect(
        '@available(iOS $kLiveActivityMinIosVersion, *)'.allMatches(
          pluginSwift,
        ),
        hasLength(2),
      );
      expect(pluginSwift, contains('#if canImport(ActivityKit)'));
    });

    test('a card is a definition key plus an instance id', () {
      expect(
        pluginSwift,
        contains('activity.attributes.definitionKey == definitionKey'),
      );
      expect(
        pluginSwift,
        contains('activity.attributes.instanceId == instanceId'),
      );
      // Absent instance id: the definition's single default card.
      expect(
        pluginSwift,
        contains('args["$kLiveActivityArgInstanceId"] as? String ?? ""'),
      );
    });

    test('update merges the changed keys into the running state', () {
      expect(
        'activity.content.state.values.merging(values)'.allMatches(pluginSwift),
        hasLength(2),
      );
    });

    test('end maps the dismissal values, immediate when absent', () {
      expect(kLiveActivityDismissalDefault, kLiveActivityDismissalImmediate);
      expect(
        pluginSwift,
        contains(
          'args["$kLiveActivityArgDismissal"] as? String '
          '?? "$kLiveActivityDismissalDefault"',
        ),
      );
      expect(
        pluginSwift,
        contains(
          'dismissal == "$kLiveActivityDismissalSystemDefault" '
          '? .default : .immediate',
        ),
      );
    });
  });

  group('widget', () {
    test('knows every template of the contract', () {
      for (final template in _fixedTemplates) {
        expect(
          widget,
          contains('case ${template.wireName} = "${template.wireName}"'),
          reason: template.wireName,
        );
      }
    });

    test('reads every value key of the contract', () {
      final keys = {
        for (final template in _fixedTemplates)
          for (final value in template.fixedValues) value.key,
      };
      for (final key in keys) {
        expect(widget, contains('("$key")'), reason: key);
      }
    });

    test('every presentation switches over every template', () {
      // Lock screen, expanded leading / trailing / bottom, compact leading /
      // trailing, minimal.
      for (final view in [
        'FFLockScreenView',
        'FFExpandedLeading',
        'FFExpandedTrailing',
        'FFExpandedBottom',
        'FFCompactLeading',
        'FFCompactTrailing',
        'FFMinimal',
      ]) {
        final start = widget.indexOf('struct $view: View');
        expect(start, isNonNegative, reason: view);
        final next = widget.indexOf('\nstruct ', start + 1);
        final body = widget.substring(start, next < 0 ? widget.length : next);
        expect(body, contains('switch card.template'), reason: view);
        for (final template in _fixedTemplates) {
          // Expanded leading shares one layout between two templates.
          if (view == 'FFExpandedLeading' &&
              (template == LiveActivityTemplate.progress ||
                  template == LiveActivityTemplate.etaTimer)) {
            expect(body, contains('default:'));
            continue;
          }
          expect(
            body,
            contains('case .${template.wireName}:'),
            reason: '$view ${template.wireName}',
          );
        }
      }
      for (final region in [
        'compactLeading:',
        'compactTrailing:',
        'minimal:',
      ]) {
        expect(widget, contains('} $region {'));
      }
      expect('DynamicIslandExpandedRegion('.allMatches(widget), hasLength(3));
    });

    test(
      'compact regions have fixed widths so the island never clips them',
      () {
        for (final view in ['FFCompactLeading', 'FFCompactTrailing']) {
          final start = widget.indexOf('struct $view: View');
          final next = widget.indexOf('\nstruct ', start + 1);
          final body = widget.substring(start, next < 0 ? widget.length : next);
          for (final template in _fixedTemplates) {
            final caseStart = body.indexOf('case .${template.wireName}:');
            expect(
              caseStart,
              isNonNegative,
              reason: '$view ${template.wireName}',
            );
            final caseEnd = body.indexOf('\n    case .', caseStart + 1);
            final block = body.substring(
              caseStart,
              caseEnd < 0 ? body.length : caseEnd,
            );
            expect(
              block,
              contains('.ffCompactFit(width:'),
              reason: '$view ${template.wireName}',
            );
          }
        }
        final helper = widget.indexOf('func ffCompactFit(');
        expect(helper, isNonNegative);
        final helperBody = widget.substring(helper, helper + 400);
        expect(helperBody, contains('.minimumScaleFactor('));
        expect(helperBody, contains('.frame(width: width'));
      },
    );

    test('the timer counts down without updates', () {
      expect(widget, contains('Text(timerInterval:'));
      expect(
        'ProgressView(\n        timerInterval:'.allMatches(widget),
        hasLength(2),
      );
    });

    test('accent colour and icon come from the attributes', () {
      expect(widget, contains('Color(ffHex: attributes.accentColor)'));
      expect(
        widget,
        contains('FFIconLoader.image(bundlePath: attributes.icon)'),
      );
    });
  });

  test('no contract name is retyped in the generator source', () {
    final source = File('lib/src/ios/swift_templates.dart').readAsStringSync();
    final names = <String>{
      kLiveActivityChannelName,
      ...kLiveActivityMethods,
      for (final keys in kLiveActivityMethodArguments.values) ...keys,
      kLiveActivityDismissalImmediate,
      kLiveActivityDismissalSystemDefault,
      for (final template in _fixedTemplates) ...[
        template.wireName,
        for (final value in template.fixedValues) value.key,
      ],
    };
    for (final name in names) {
      expect(source, isNot(contains('"$name"')), reason: name);
      expect(source, isNot(contains("'$name'")), reason: name);
    }
    expect(source, isNot(contains(kLiveActivityChannelName)));
  });

  group('Info.plist', () {
    test('the app declares NSSupportsLiveActivities', () {
      expect(
        liveActivityRunnerInfoPlistEntries(app),
        kLiveActivityRunnerInfoPlistEntries,
      );
      expect(
        kLiveActivityRunnerInfoPlistEntries,
        contains('<key>NSSupportsLiveActivities</key>\n    <true/>'),
      );
    });
  });
}
