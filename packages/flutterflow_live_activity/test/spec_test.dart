import 'package:flutterflow_live_activity/flutterflow_live_activity.dart';
import 'package:test/test.dart';

import 'test_specs.dart';

void main() {
  test('an app reads the spec version of this package', () {
    expect(appWith(const []).specVersion, kLiveActivitySpecVersion);
    expect(kLiveActivitySpecVersion, 1);
  });

  group('surfaces', () {
    test('have the sizes iOS gives them, in points', () {
      expect(
        {
          for (final surface in LiveActivitySurface.values)
            surface: (surface.width, surface.height),
        },
        {
          LiveActivitySurface.lockScreen: (371, 160),
          LiveActivitySurface.islandExpanded: (371, 122),
          LiveActivitySurface.islandCompactLeading: (52, 36),
          LiveActivitySurface.islandCompactTrailing: (52, 36),
          LiveActivitySurface.islandMinimal: (36, 36),
        },
      );
    });

    test('name the card views', () {
      expect(LiveActivitySurface.values.map((s) => s.swiftName), [
        'lockScreen',
        'expanded',
        'compactLeading',
        'compactTrailing',
        'minimal',
      ]);
      expect(
        liveActivityCardViewName(
          rideCard(key: 'la-ride 2'),
          LiveActivitySurface.islandExpanded,
        ),
        'FFCard_la_ride_2_expanded',
      );
    });

    test('only the Lock Screen is off the island', () {
      expect(LiveActivitySurface.values.where((s) => !s.isIsland), [
        LiveActivitySurface.lockScreen,
      ]);
    });

    test('a card lists its layouts in surface order', () {
      final minimal = compactLayout();
      final lock = lockLayout();
      final card = rideCard(
        surfaces: {
          LiveActivitySurface.islandMinimal: minimal,
          LiveActivitySurface.lockScreen: lock,
        },
      );
      expect(card.layouts, [
        (LiveActivitySurface.lockScreen, lock),
        (LiveActivitySurface.islandMinimal, minimal),
      ]);
      expect(card.anyNode((node) => node is LayoutIcon), isTrue);
      expect(card.anyNode((node) => node is LayoutStack), isFalse);
    });
  });

  test('every value type but text and image has an encoder', () {
    expect(
      {for (final type in LiveActivityValueType.values) type: type.encoder},
      {
        LiveActivityValueType.string: null,
        LiveActivityValueType.integer: kLiveActivityEncodeInt,
        LiveActivityValueType.double: kLiveActivityEncodeDouble,
        LiveActivityValueType.boolean: kLiveActivityEncodeBool,
        LiveActivityValueType.dateTime: kLiveActivityEncodeDateTime,
        LiveActivityValueType.color: kLiveActivityEncodeColor,
        LiveActivityValueType.image: null,
      },
    );
  });

  group('a value', () {
    final card = rideCard();

    test('is found by its key', () {
      expect(card.value('v_eta')!.type, LiveActivityValueType.dateTime);
      expect(card.value('v_missing'), isNull);
      expect(card.value(''), isNull);
    });

    test('of a type, in order', () {
      expect(
        card.valuesOfType(LiveActivityValueType.string).map((v) => v.key),
        ['v_title', 'v_driver'],
      );
      expect(card.imageValues.map((v) => v.key), ['v_photo']);
    });
  });

  group('Android slots', () {
    test('take the values of their type in order when not named', () {
      final slots = rideCard().androidSlotValues;
      expect(
        {for (final e in slots.entries) e.key: e.value.key},
        {
          LiveActivityAndroidSlot.title: 'v_title',
          LiveActivityAndroidSlot.text: 'v_driver',
          LiveActivityAndroidSlot.progress: 'v_done',
          LiveActivityAndroidSlot.countdown: 'v_eta',
          LiveActivityAndroidSlot.largeIcon: 'v_photo',
        },
      );
    });

    test(
      'a named value wins; a named value the card lacks leaves it empty',
      () {
        final card = rideCard(
          android: const LiveActivityAndroid(
            slots: {
              LiveActivityAndroidSlot.title: 'v_driver',
              LiveActivityAndroidSlot.shortText: 'v_title',
              LiveActivityAndroidSlot.progress: 'v_gone',
              LiveActivityAndroidSlot.largeIcon: '',
            },
          ),
        );
        expect(
          {for (final e in card.androidSlotValues.entries) e.key: e.value.key},
          {
            LiveActivityAndroidSlot.title: 'v_driver',
            LiveActivityAndroidSlot.text: 'v_driver',
            LiveActivityAndroidSlot.countdown: 'v_eta',
            LiveActivityAndroidSlot.shortText: 'v_title',
          },
        );
      },
    );

    test('a card without values fills none', () {
      expect(rideCard(values: const []).androidSlotValues, isEmpty);
    });

    test('are named as the Kotlin side reads them', () {
      expect(LiveActivityAndroidSlot.values.map((slot) => slot.name), [
        'title',
        'text',
        'progress',
        'countdown',
        'shortText',
        'largeIcon',
      ]);
      expect(LiveActivityAndroidSlot.values.map((slot) => slot.valueType), [
        LiveActivityValueType.string,
        LiveActivityValueType.string,
        LiveActivityValueType.double,
        LiveActivityValueType.dateTime,
        LiveActivityValueType.string,
        LiveActivityValueType.image,
      ]);
    });
  });

  group('defaults', () {
    test('iOS draws every default but an image, empty text too', () {
      expect(rideCard().iosDefaults, {
        'v_title': 'Your ride',
        'v_driver': '',
        'v_done': '0.25',
        'v_accent': '#FF39D2C0',
      });
    });

    test('Android draws the values\' non-empty defaults but an image', () {
      expect(rideCard().androidValueDefaults, {
        'v_title': 'Your ride',
        'v_done': '0.25',
        'v_accent': '#FF39D2C0',
      });
    });

    test('a table of Android defaults replaces the values\' own', () {
      expect(
        rideCard(
          androidDefaults: const {'v_eta': '1700000000000'},
        ).androidValueDefaults,
        {'v_eta': '1700000000000'},
      );
      expect(rideCard(androidDefaults: const {}).androidValueDefaults, isEmpty);
    });

    test('an Image value falls back to its default picture', () {
      expect(rideCard().imageFallbacks, {
        'v_photo': 'assets/images/driver.png',
      });
      expect(
        rideCard(
          values: const [
            LiveActivityValue(key: 'v_pic', type: LiveActivityValueType.image),
          ],
        ).imageFallbacks,
        isEmpty,
      );
    });
  });

  group('an app', () {
    final ride = rideCard();
    final noImage = rideCard(
      key: 'la_plain',
      values: const [
        LiveActivityValue(key: 'v_title', type: LiveActivityValueType.string),
      ],
    );
    final order = fixedCard(LiveActivityTemplate.etaTimer);

    test('lists its Custom cards and those with an Image value', () {
      final app = appWith([order, noImage, ride]);
      expect(app.customCards, [noImage, ride]);
      expect(app.hasCustomCards, isTrue);
      expect(app.imageCards, [ride]);
      expect(app.hasImageValues, isTrue);
    });

    test('of fixed templates has neither', () {
      final app = appWith([order]);
      expect(app.customCards, isEmpty);
      expect(app.hasCustomCards, isFalse);
      expect(app.hasImageValues, isFalse);
      expect(order.isCustom, isFalse);
      expect(ride.isCustom, isTrue);
    });

    test('shares a keychain group with the extension', () {
      final app = appWith(const []);
      expect(app.appKeychainGroup, r'$(AppIdentifierPrefix)com.example.rides');
      expect(
        app.keychainGroup,
        r'$(AppIdentifierPrefix)com.example.rides.liveactivity',
      );
      expect(liveActivityKeychainGroup(bundleId), app.keychainGroup);
    });

    test('a key is part of the native names as an identifier', () {
      expect(rideCard(key: 'la-ride.2').nativeKey, 'la_ride_2');
    });
  });
}
