// What a Custom card adds to the generated files: its SwiftUI views, the
// pictures of its Image values, its Android card spec and drawing, and the
// icons the Dart plugin keeps.
import 'dart:io';

import 'package:flutterflow_live_activity/flutterflow_live_activity.dart';
import 'package:test/test.dart';

import 'test_specs.dart';

const _extension = 'ios/$kLiveActivityIosExtensionTarget';
const _android = '$kLiveActivityPluginPackagePath/android/src/main';

/// The body of Swift struct [name] in [source].
String _struct(String source, String name) {
  final start = source.indexOf('struct $name');
  expect(start, isNot(-1), reason: name);
  final end = source.indexOf('\nstruct ', start + 1);
  return source.substring(start, end == -1 ? source.length : end);
}

void main() {
  group('the generated files', () {
    test('an app with fixed templates only gets no card files', () {
      final files = generateLiveActivityFiles(
        appWith([fixedCard(LiveActivityTemplate.queueStatus)]),
      );
      expect(
        files.keys.where(
          (path) =>
              path.endsWith(kLiveActivityIosCardsSwiftFile) ||
              path.endsWith(kLiveActivityIosEntitlementsFile) ||
              path.endsWith('FFLiveActivityCustom.kt') ||
              path.contains('/res/'),
        ),
        isEmpty,
      );
    });

    test('a Custom card adds its views, entitlements and card spec', () {
      final files = generateLiveActivityFiles(appWith([rideCard()]));
      expect(
        files.keys,
        containsAll([
          '$_extension/$kLiveActivityIosCardsSwiftFile',
          '$_extension/$kLiveActivityIosEntitlementsFile',
          '$_android/kotlin/$kLiveActivityAndroidKotlinDir/'
              'FFLiveActivityCustom.kt',
        ]),
      );
      // Standard Live Update on Android: nothing drawn.
      expect(files.keys.where((path) => path.contains('/res/')), isEmpty);
    });

    test('without an Image value there are no entitlements', () {
      final files = generateLiveActivityFiles(
        appWith([
          rideCard(
            values: const [
              LiveActivityValue(
                key: 'v_driver',
                type: LiveActivityValueType.string,
              ),
            ],
          ),
        ]),
      );
      expect(
        files.keys,
        isNot(contains('$_extension/$kLiveActivityIosEntitlementsFile')),
      );
      expect(
        files['$_extension/Info.plist'],
        isNot(contains(kLiveActivityKeychainGroupInfoPlistKey)),
      );
    });

    test('are every file of the three parts, nothing else', () {
      final app = appWith([
        rideCard(
          android: const LiveActivityAndroid(
            presentation: LiveActivityAndroidPresentation.custom,
          ),
        ),
      ]);
      expect(generateLiveActivityFiles(app), {
        ...liveActivityDartPackageFiles(app),
        ...liveActivityIosFiles(app),
        ...liveActivityAndroidFiles(app),
      });
    });
  });

  test('refuses an expanded island layout shared with another surface', () {
    final shared = lockLayout();
    expect(
      () => liveActivityCardsSwift(
        appWith([
          rideCard(
            surfaces: {
              LiveActivitySurface.lockScreen: shared,
              LiveActivitySurface.islandExpanded: shared,
            },
          ),
        ]),
      ),
      throwsArgumentError,
    );
  });

  group('the cards Swift', () {
    final lock = lockLayout();
    final expanded = expandedLayout();
    final swift = liveActivityCardsSwift(
      appWith(
        [
          rideCard(
            surfaces: {
              LiveActivitySurface.lockScreen: lock,
              LiveActivitySurface.islandExpanded: expanded,
            },
          ),
        ],
        routes: const LiveActivityRoutes(
          scheme: 'rides',
          host: 'open',
          encodeTwice: false,
        ),
      ),
    );

    test('has a view per designed surface, named after the card', () {
      for (final view in [
        'FFCard_la_ride_lockScreen',
        'FFCard_la_ride_expanded',
      ]) {
        expect(swift, contains('struct $view: View'), reason: view);
      }
      expect(swift, isNot(contains('FFCard_la_ride_minimal')));
    });

    test('the Lock Screen fill tints the card', () {
      expect(
        _struct(swift, 'FFCustomLockScreen'),
        contains('.activityBackgroundTint('),
      );
    });

    test('the expanded island drops the top fill', () {
      expect((expanded.root! as LayoutBox).background, isNull);
      expect((lock.root! as LayoutBox).background, isNotNull);
    });

    test('the island is drawn dark; the Lock Screen follows the phone', () {
      expect(
        _struct(swift, 'FFCustomExpanded'),
        contains('.environment(\\.colorScheme, .dark)'),
      );
      expect(
        _struct(swift, 'FFCustomLockScreen'),
        isNot(contains('.colorScheme')),
      );
    });

    test('names the app\'s deep link', () {
      expect(swift, contains('let kFFRouteScheme = "rides"'));
      expect(swift, contains('let kFFRouteHost = "open"'));
      expect(swift, contains('let kFFRouteEncodeTwice = false'));
    });

    test('carries the iOS defaults, but no image', () {
      expect(swift, contains('"v_title": "Your ride",'));
      expect(swift, contains('"v_driver": "",'));
      expect(swift, contains('"v_accent": "#FF39D2C0",'));
      expect(swift, isNot(contains('"v_photo": "assets')));
      expect(swift, contains('"la_ride": ["v_photo"],'));
      expect(swift, contains(kLiveActivityExtensionImageStoreSwift));
    });

    test('a compact side without a layout is derived from the values', () {
      // A countdown to the first date value.
      expect(
        _struct(swift, 'FFCustomCompactTrailing'),
        contains('FFCustomCountdown(end: card.values.date("v_eta"))'),
      );
      // Else a ring of the first Double value.
      final ring = liveActivityCardsSwift(
        appWith([
          rideCard(
            values: const [
              LiveActivityValue(
                key: 'v_done',
                type: LiveActivityValueType.double,
              ),
            ],
          ),
        ]),
      );
      expect(
        _struct(ring, 'FFCustomCompactTrailing'),
        contains('value: card.values.double("v_done"),'),
      );
      // Else nothing.
      final none = liveActivityCardsSwift(
        appWith([rideCard(values: const [])]),
      );
      expect(
        _struct(none, 'FFCustomCompactTrailing'),
        contains('case "la_ride":\n        EmptyView()'),
      );
      expect(
        _struct(none, 'FFCustomCompactLeading'),
        contains('FFIconView(card: card.fixed, size: 18)'),
      );
    });

    test('a designed compact side has the island\'s size', () {
      final designed = liveActivityCardsSwift(
        appWith([
          rideCard(
            surfaces: {
              LiveActivitySurface.islandCompactLeading: compactLayout(),
              LiveActivitySurface.islandMinimal: compactLayout(),
            },
          ),
        ]),
      );
      expect(
        designed,
        contains('.frame(width: 52, height: 36, alignment: .leading)'),
      );
      expect(
        designed,
        contains('.frame(width: 36, height: 36, alignment: .center)'),
      );
      expect(
        _struct(designed, 'FFCustomLockScreen'),
        contains('case "la_ride":\n        EmptyView()'),
      );
    });
  });

  group('pictures of Image values', () {
    test('are stored at the largest side that draws them, times 3', () {
      expect(liveActivityImageTargets(appWith([rideCard()])), {
        'la_ride': {'v_photo': 120},
      });
      expect(
        liveActivityImageTargets(
          appWith([
            rideCard(
              surfaces: {
                LiveActivitySurface.lockScreen: lockLayout(photoSide: 20),
                LiveActivitySurface.islandCompactTrailing: compactLayout(
                  photo: true,
                ),
              },
            ),
          ]),
        ),
        {
          // A fitted image is as long as its surface: 52 points.
          'la_ride': {'v_photo': 156},
        },
      );
    });

    test('at most the cap; a value no node draws gets the cap', () {
      expect(
        liveActivityImageTargets(
          appWith([
            rideCard(
              surfaces: {
                LiveActivitySurface.lockScreen: lockLayout(photoSide: 600),
              },
            ),
            rideCard(key: 'la_bare', surfaces: const {}),
          ]),
        ),
        {
          'la_ride': {'v_photo': kLiveActivityImageMaxPixels},
          'la_bare': {'v_photo': kLiveActivityImageMaxPixels},
        },
      );
    });

    test('a fixed template or a card without one stores none', () {
      expect(
        liveActivityImageTargets(
          appWith([
            fixedCard(LiveActivityTemplate.progress),
            rideCard(values: const []),
          ]),
        ),
        isEmpty,
      );
    });

    test('share a keychain group the app and the extension both name', () {
      final app = appWith([rideCard()]);
      final files = liveActivityIosFiles(app);
      final group = '<string>${app.keychainGroup}</string>';
      expect(
        files['$_extension/$kLiveActivityIosEntitlementsFile'],
        contains(group),
      );
      expect(files['$_extension/Info.plist'], contains(group));
      expect(liveActivityRunnerInfoPlistEntries(app), contains(group));
      expect(
        liveActivityRunnerInfoPlistEntries(app),
        startsWith(kLiveActivityRunnerInfoPlistEntries),
      );
      expect(liveActivityKeychainGroupInfoPlistEntry(appWith(const [])), '');
    });
  });

  group('Android', () {
    String customKotlin(LiveActivityApp app) =>
        liveActivityAndroidFiles(app)['$_android/kotlin/'
            '$kLiveActivityAndroidKotlinDir/FFLiveActivityCustom.kt']!;

    test('the card spec names its slots, defaults and fallbacks', () {
      final kotlin = customKotlin(appWith([rideCard()]));
      expect(
        kotlin,
        contains(
          '"la_ride" to FFCardSpec(\n'
          '            mapOf("title" to "v_title", "text" to "v_driver", '
          '"progress" to "v_done", "countdown" to "v_eta", '
          '"largeIcon" to "v_photo"),\n'
          '            mapOf("v_title" to "Your ride", "v_done" to "0.25", '
          '"v_accent" to "#FF39D2C0"),\n'
          '            mapOf("v_photo" to "assets/images/driver.png"),\n',
        ),
      );
    });

    test('a table of Android defaults replaces the values\' own', () {
      final kotlin = customKotlin(
        appWith([
          rideCard(androidDefaults: const {'v_driver': 'Sam'}),
        ]),
      );
      expect(kotlin, contains('            mapOf("v_driver" to "Sam"),\n'));
    });

    test('Custom drawing draws the Lock Screen layout', () {
      final app = appWith([
        rideCard(
          android: const LiveActivityAndroid(
            presentation: LiveActivityAndroidPresentation.custom,
          ),
        ),
      ]);
      expect(liveActivityHasDrawnCustomCards(app), isTrue);
      final files = liveActivityAndroidFiles(app);
      expect(
        files.keys,
        contains('$_android/res/layout/hw_layout_la_la_ride.xml'),
      );
      expect(
        files.keys,
        containsAll([
          '$_android/res/values/ff_live_activity_colors.xml',
          '$_android/res/values-night/ff_live_activity_colors.xml',
        ]),
      );
      expect(customKotlin(app), contains(kotlinBinderName('la_la_ride')));
    });

    test('a tap keeps the standard Live Update and says where it is', () {
      final card = rideCard(
        surfaces: {
          LiveActivitySurface.lockScreen: lockLayout(
            tap: const LayoutOpenPage('/ride', []),
          ),
        },
        android: const LiveActivityAndroid(
          presentation: LiveActivityAndroidPresentation.custom,
        ),
      );
      expect(liveActivityAndroidTapDroppingDrawing(card), 'Container_1');
      expect(liveActivityHasDrawnCustomCards(appWith([card])), isFalse);
      expect(
        liveActivityAndroidFiles(
          appWith([card]),
        ).keys.where((path) => path.contains('/res/')),
        isEmpty,
      );
      // Not set to Custom drawing: nothing is dropped.
      expect(liveActivityAndroidTapDroppingDrawing(rideCard()), isNull);
    });

    test('the standard bar follows a timed first bar', () {
      final bar =
          LayoutProgress(
              'Bar_7',
              circular: false,
              value: const LayoutFraction.fixed(0),
            )
            ..timedStart = 'v_start'
            ..timedEnd = 'v_eta';
      final card = rideCard(
        surfaces: {
          LiveActivitySurface.lockScreen: NativeLayoutModel(bar, const []),
        },
      );
      final timed = liveActivityAndroidStandardTimed(card);
      expect(timed.timedStart, 'v_start');
      expect(timed.timedEnd, 'v_eta');
      expect(timed.countUp, isFalse);
      // Not when the card names a value for the bar.
      final named = liveActivityAndroidStandardTimed(
        rideCard(
          surfaces: card.surfaces,
          android: const LiveActivityAndroid(
            slots: {LiveActivityAndroidSlot.progress: 'v_done'},
          ),
        ),
      );
      expect(named.timedStart, isNull);
    });
  });

  group('icons', () {
    test('the cards\' icons are kept in the Dart plugin', () {
      final app = appWith([
        rideCard(
          surfaces: {
            LiveActivitySurface.lockScreen: lockLayout(),
            LiveActivitySurface.islandMinimal: compactLayout(),
          },
        ),
      ]);
      expect(liveActivityCardIconCodePoints(app), {0xe1d7, 0xe531});
      final library =
          liveActivityDartPackageFiles(app)[kLiveActivityPluginDartPath]!;
      expect(
        library,
        contains(
          "  IconData(0xe1d7, fontFamily: 'MaterialIcons'),\n"
          "  IconData(0xe531, fontFamily: 'MaterialIcons'),\n",
        ),
      );
    });

    test('a fixed template keeps none', () {
      expect(
        liveActivityCardIconCodePoints(
          appWith([fixedCard(LiveActivityTemplate.score)]),
        ),
        isEmpty,
      );
    });
  });

  test('no contract name is retyped in the generator sources', () {
    final names = <String>{
      kLiveActivityChannelName,
      kLiveActivityArgImages,
      kLiveActivityArgValues,
      kLiveActivityArgDefinitionKey,
      kLiveActivityArgInstanceId,
      kLiveActivityCustomTemplateName,
      kLiveActivityImageSourceUrl,
      kLiveActivityImageSourcePath,
      kLiveActivityImageSourceBytes,
      kLiveActivityImageSourceAsset,
    };
    for (final file in ['custom_cards.dart', 'image_store.dart']) {
      final source = File('lib/src/ios/$file').readAsStringSync();
      for (final name in names) {
        expect(source, isNot(contains('"$name"')), reason: '$file: $name');
      }
    }
  });
}
