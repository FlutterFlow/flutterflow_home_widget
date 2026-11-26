// The Xcode project text of the Live Activity widget-extension target.
import 'package:flutterflow_live_activity/flutterflow_live_activity.dart';
import 'package:test/test.dart';

import 'test_specs.dart';

void main() {
  const target = kLiveActivityIosExtensionTarget;
  final fixedOnly = appWith([fixedCard(LiveActivityTemplate.progress)]);
  final fragments = liveActivityPbxprojFragments(fixedOnly);
  final all = fragments.join();

  test('there is one fragment per slot, for every kind of app', () {
    expect(kLiveActivityPbxprojSlots, hasLength(18));
    for (final app in [
      fixedOnly,
      appWith([rideCard()]),
      appWith([rideCard(values: const [])]),
    ]) {
      expect(
        liveActivityPbxprojFragments(app),
        hasLength(kLiveActivityPbxprojSlots.length),
      );
    }
  });

  test('the app gives the bundle id and the device family', () {
    expect(
      fragments,
      liveActivityPbxprojFragmentsFor(
        bundleId: bundleId,
        targetDeviceFamily: '1',
      ),
    );
    expect(
      'PRODUCT_BUNDLE_IDENTIFIER = $bundleId.$target;'.allMatches(all),
      hasLength(3),
    );
    expect('TARGETED_DEVICE_FAMILY = "1";'.allMatches(all), hasLength(3));
  });

  test('the device family is quoted whether or not it comes quoted', () {
    for (final family in ['1,2', '"1,2"']) {
      expect(
        'TARGETED_DEVICE_FAMILY = "1,2";'.allMatches(
          liveActivityPbxprojFragments(
            appWith(const [], deviceFamily: family),
          ).join(),
        ),
        hasLength(3),
        reason: family,
      );
    }
    expect(
      liveActivityPbxprojFragments(appWith(const [], deviceFamily: '"1"')),
      fragments,
    );
  });

  test('the names and the deployment target come from the contract', () {
    expect(
      'IPHONEOS_DEPLOYMENT_TARGET = $kLiveActivityMinIosVersion;'.allMatches(
        all,
      ),
      hasLength(3),
    );
    expect(
      'INFOPLIST_FILE = $target/Info.plist;'.allMatches(all),
      hasLength(3),
    );
    expect(all, contains('path = $kLiveActivityIosAttributesSwiftFile;'));
    expect(all, contains('path = $kLiveActivityIosBundleSwiftFile;'));
    expect(all, contains('path = $target.appex;'));
    expect(all, contains('remoteInfo = $target;'));
    expect(all, contains('name = "$kLiveActivityIosEmbedPhaseName";'));
  });

  test(
    'a Custom card adds its Swift file; an Image value signs the target',
    () {
      expect(all, isNot(contains(kLiveActivityIosCardsSwiftFile)));
      expect(all, isNot(contains('CODE_SIGN_ENTITLEMENTS')));

      final custom =
          liveActivityPbxprojFragments(
            appWith([rideCard(values: const [])]),
          ).join();
      expect(
        custom,
        contains('/* $kLiveActivityIosCardsSwiftFile in Sources */,'),
      );
      expect(custom, isNot(contains('CODE_SIGN_ENTITLEMENTS')));

      final images = liveActivityPbxprojFragments(appWith([rideCard()])).join();
      expect(
        'CODE_SIGN_ENTITLEMENTS = $target/$kLiveActivityIosEntitlementsFile;'
            .allMatches(images),
        hasLength(3),
      );
    },
  );

  test('object ids are the target\'s own', () {
    final images = liveActivityPbxprojFragments(appWith([rideCard()])).join();
    final ids =
        RegExp(
          r'[0-9A-F]{24}',
        ).allMatches(images).map((m) => m.group(0)!).toSet();
    final own = ids.where((id) => id.startsWith('11AC71')).toSet();
    // 19 objects, the Swift file of the cards (2) and the entitlements.
    expect(own, hasLength(22));
    // The project object is the one id it refers to and does not own.
    expect(ids.difference(own), {'97C146E61CF9000F007C117D'});
  });
}
