import 'package:flutterflow_live_activity/src/contract.dart';
import 'package:flutterflow_live_activity/src/spec.dart';

/// File names of the widget extension's two Swift sources, in the order the
/// Xcode target lists them. `swift_templates.dart` writes files with these
/// names; the target compiles exactly these.
const kLiveActivityIosBundleSwiftFile =
    '${kLiveActivityIosExtensionTarget}Bundle.swift';
const kLiveActivityIosAttributesSwiftFile =
    '$kLiveActivityAttributesType.swift';

/// The Swift source of the Custom cards' views (`custom_cards.dart`). In the
/// target only when the app has a Custom card.
const kLiveActivityIosCardsSwiftFile =
    '${kLiveActivityIosExtensionTarget}Cards.swift';

/// The extension's entitlements file (`image_store.dart`). In the target
/// only when a Custom card has an Image value.
const kLiveActivityIosEntitlementsFile =
    '$kLiveActivityIosExtensionTarget.entitlements';

/// Name of the copy-files phase that embeds the extension into the app. Its
/// own phase, not the push extension's "Embed App Extensions", so neither
/// feature depends on the other being on.
const kLiveActivityIosEmbedPhaseName = 'Embed Live Activity Extension';

/// Xcode object ids of the target. Fixed, so the same app always generates
/// the same file. They collide neither with a project made by
/// `flutter create` (`97C1…`, `7485…`, …), nor with the ImageNotification
/// (`6430E6…`) or HomeWidget (`11AC72…`) targets.
String _id(int n) =>
    '11AC71${n.toRadixString(16).toUpperCase().padLeft(2, '0')}'
    '2CF0000100A0B0C0';

final _buildBundleSwift = _id(0x01);
final _buildAttributesSwift = _id(0x02);
final _buildAppex = _id(0x03);
final _containerProxy = _id(0x04);
final _targetDependency = _id(0x05);
final _embedPhase = _id(0x06);
final _refAppex = _id(0x07);
final _refBundleSwift = _id(0x08);
final _refAttributesSwift = _id(0x09);
final _refInfoPlist = _id(0x0A);
final _frameworksPhase = _id(0x0B);
final _sourcesPhase = _id(0x0C);
final _resourcesPhase = _id(0x0D);
final _group = _id(0x0E);
final _target = _id(0x0F);
final _configDebug = _id(0x10);
final _configRelease = _id(0x11);
final _configProfile = _id(0x12);
final _configList = _id(0x13);
final _buildCardsSwift = _id(0x14);
final _refCardsSwift = _id(0x15);
final _refEntitlements = _id(0x16);

/// The template's project object, the container of every target.
const _kProjectObject = '97C146E61CF9000F007C117D';

/// The pbxproj text of the Live Activity widget-extension target, one
/// fragment per slot of [kLiveActivityPbxprojSlots], in that order. Each goes
/// into the section its slot names in a project made by `flutter create`; a
/// project that already has other extensions composes its fragments with
/// theirs, slot by slot.
List<String> liveActivityPbxprojFragments(LiveActivityApp app) =>
    liveActivityPbxprojFragmentsFor(
      bundleId: app.iosBundleId,
      targetDeviceFamily: app.iosDeviceFamily,
      customCards: app.hasCustomCards,
      imageValues: app.hasImageValues,
    );

/// Where each fragment of [liveActivityPbxprojFragments] goes. Every
/// fragment starts on a new line of its own and ends without one, because
/// each slot sits at the end of the line it extends. Slots 0 and 3 are the
/// exception: they sit at the start of a line, so their fragments are whole
/// lines. Slot 1 is alone on a line and takes a whole section.
const kLiveActivityPbxprojSlots = [
  'PBXBuildFile entries',
  'PBXContainerItemProxy section: the proxy the Runner depends on the target through',
  'PBXCopyFilesBuildPhase: the phase that embeds the extension (PlugIns)',
  'PBXFileReference entries',
  "PBXFrameworksBuildPhase: the target's (empty) frameworks phase",
  "PBXGroup: the group of the extension's folder",
  "the group, in the project's root group's children",
  "the product, in the Products group's children",
  'PBXNativeTarget: the target',
  "the embed phase, in the Runner's buildPhases",
  "the Runner's dependency on the target, in its dependencies",
  'TargetAttributes of the project',
  "the target, in the project's targets",
  "PBXResourcesBuildPhase: the target's (empty) resources phase",
  "PBXSourcesBuildPhase: the target's sources phase",
  'PBXTargetDependency section: the dependency object',
  'XCBuildConfiguration: the three build configurations',
  'XCConfigurationList: their list',
];

/// [liveActivityPbxprojFragments] from plain values.
///
/// [targetDeviceFamily] is `1` or `1,2`, quoted or not; the project file
/// has it quoted.
///
/// [customCards] adds the Custom cards' Swift file to the target;
/// [imageValues] signs the target with its entitlements file (the keychain
/// group the pictures are in). Without them the text is what it was before
/// Custom cards existed.
List<String> liveActivityPbxprojFragmentsFor({
  required String bundleId,
  required String targetDeviceFamily,
  bool customCards = false,
  bool imageValues = false,
}) {
  const cardsSwift = kLiveActivityIosCardsSwiftFile;
  const entitlements = kLiveActivityIosEntitlementsFile;
  const target = kLiveActivityIosExtensionTarget;
  const bundleSwift = kLiveActivityIosBundleSwiftFile;
  const attributesSwift = kLiveActivityIosAttributesSwiftFile;
  const embedPhase = kLiveActivityIosEmbedPhaseName;

  String buildConfiguration(String id, String name) {
    final isDebug = name == 'Debug';
    return '''

		$id /* $name */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++14";
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
${imageValues ? '''
				CODE_SIGN_ENTITLEMENTS = $target/$entitlements;
''' : ''}				CODE_SIGN_STYLE = Automatic;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				INFOPLIST_FILE = $target/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = $kLiveActivityMinIosVersion;
				LD_RUNPATH_SEARCH_PATHS = (
					"\$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
${isDebug ? '''
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
''' : ''}				MTL_FAST_MATH = YES;
				PRODUCT_BUNDLE_IDENTIFIER = $bundleId.$target;
				PRODUCT_NAME = "\$(TARGET_NAME)";
				SKIP_INSTALL = YES;
${isDebug ? '''
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
''' : ''}				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "${targetDeviceFamily.replaceAll('"', '')}";
			};
			name = $name;
		};''';
  }

  final fragments = <String>[
    // 0: PBXBuildFile entries.
    '''
		$_buildBundleSwift /* $bundleSwift in Sources */ = {isa = PBXBuildFile; fileRef = $_refBundleSwift /* $bundleSwift */; };
		$_buildAttributesSwift /* $attributesSwift in Sources */ = {isa = PBXBuildFile; fileRef = $_refAttributesSwift /* $attributesSwift */; };
${customCards ? '''
		$_buildCardsSwift /* $cardsSwift in Sources */ = {isa = PBXBuildFile; fileRef = $_refCardsSwift /* $cardsSwift */; };
''' : ''}		$_buildAppex /* $target.appex in $embedPhase */ = {isa = PBXBuildFile; fileRef = $_refAppex /* $target.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
''',
    // 1: the proxy the Runner's dependency on the target goes through.
    '''

/* Begin PBXContainerItemProxy section */
		$_containerProxy /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = $_kProjectObject /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = $_target;
			remoteInfo = $target;
		};
/* End PBXContainerItemProxy section */
''',
    // 2: the copy-files phase that embeds the extension (PlugIns = 13).
    '''

		$_embedPhase /* $embedPhase */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 13;
			files = (
				$_buildAppex /* $target.appex in $embedPhase */,
			);
			name = "$embedPhase";
			runOnlyForDeploymentPostprocessing = 0;
		};''',
    // 3: file references.
    '''
		$_refAppex /* $target.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = $target.appex; sourceTree = BUILT_PRODUCTS_DIR; };
		$_refBundleSwift /* $bundleSwift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = $bundleSwift; sourceTree = "<group>"; };
		$_refAttributesSwift /* $attributesSwift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = $attributesSwift; sourceTree = "<group>"; };
${customCards ? '''
		$_refCardsSwift /* $cardsSwift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = $cardsSwift; sourceTree = "<group>"; };
''' : ''}${imageValues ? '''
		$_refEntitlements /* $entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = $entitlements; sourceTree = "<group>"; };
''' : ''}		$_refInfoPlist /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
''',
    // 4: the target's (empty) frameworks phase.
    '''

		$_frameworksPhase /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};''',
    // 5: the group of the extension's folder.
    '''

		$_group /* $target */ = {
			isa = PBXGroup;
			children = (
				$_refBundleSwift /* $bundleSwift */,
				$_refAttributesSwift /* $attributesSwift */,
${customCards ? '''
				$_refCardsSwift /* $cardsSwift */,
''' : ''}				$_refInfoPlist /* Info.plist */,
${imageValues ? '''
				$_refEntitlements /* $entitlements */,
''' : ''}			);
			path = $target;
			sourceTree = "<group>";
		};''',
    // 6: the group, in the project's root group.
    '''

				$_group /* $target */,''',
    // 7: the product, in the Products group.
    '''

				$_refAppex /* $target.appex */,''',
    // 8: the target.
    '''

		$_target /* $target */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = $_configList /* Build configuration list for PBXNativeTarget "$target" */;
			buildPhases = (
				$_sourcesPhase /* Sources */,
				$_frameworksPhase /* Frameworks */,
				$_resourcesPhase /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = $target;
			productName = $target;
			productReference = $_refAppex /* $target.appex */;
			productType = "com.apple.product-type.app-extension";
		};''',
    // 9: the embed phase, in the Runner's build phases.
    '''

				$_embedPhase /* $embedPhase */,''',
    // 10: the Runner's dependency on the target.
    '''

				$_targetDependency /* PBXTargetDependency */,''',
    // 11: target attributes.
    '''

					$_target = {
						CreatedOnToolsVersion = 14.1;
					};''',
    // 12: the target, in the project's target list.
    '''

				$_target /* $target */,''',
    // 13: the target's (empty) resources phase.
    '''

		$_resourcesPhase /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};''',
    // 14: the target's sources phase.
    '''

		$_sourcesPhase /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				$_buildBundleSwift /* $bundleSwift in Sources */,
				$_buildAttributesSwift /* $attributesSwift in Sources */,
${customCards ? '''
				$_buildCardsSwift /* $cardsSwift in Sources */,
''' : ''}			);
			runOnlyForDeploymentPostprocessing = 0;
		};''',
    // 15: the dependency object.
    '''


/* Begin PBXTargetDependency section */
		$_targetDependency /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = $_target /* $target */;
			targetProxy = $_containerProxy /* PBXContainerItemProxy */;
		};
/* End PBXTargetDependency section */''',
    // 16: the three build configurations.
    buildConfiguration(_configDebug, 'Debug') +
        buildConfiguration(_configRelease, 'Release') +
        buildConfiguration(_configProfile, 'Profile'),
    // 17: their list.
    '''

		$_configList /* Build configuration list for PBXNativeTarget "$target" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				$_configDebug /* Debug */,
				$_configRelease /* Release */,
				$_configProfile /* Profile */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};''',
  ];
  assert(fragments.length == kLiveActivityPbxprojSlots.length);
  return fragments;
}

/// [pbxproj] without the entries that put [fileName] (one of
/// [kLiveActivityIosCardsSwiftFile] or [kLiveActivityIosEntitlementsFile])
/// into the Live Activity target: its file reference, its place in the
/// extension's group and, for the Swift file, its build file and its entry
/// in the sources phase; for the entitlements file, the target's
/// `CODE_SIGN_ENTITLEMENTS` setting too. Only lines with the target's own
/// object ids (or that setting) go; the project is otherwise as it was, and
/// one without the entries is returned unchanged.
String removeLiveActivityIosFile(String pbxproj, String fileName) {
  final ids = switch (fileName) {
    kLiveActivityIosCardsSwiftFile => [_refCardsSwift, _buildCardsSwift],
    kLiveActivityIosEntitlementsFile => [_refEntitlements],
    _ => throw ArgumentError.value(fileName, 'fileName'),
  };
  final signing =
      fileName == kLiveActivityIosEntitlementsFile
          ? 'CODE_SIGN_ENTITLEMENTS = '
              '$kLiveActivityIosExtensionTarget/$kLiveActivityIosEntitlementsFile;'
          : null;
  final lines = pbxproj.split('\n');
  return [
    for (final line in lines)
      if (!ids.any(line.contains) &&
          (signing == null || line.trim() != signing))
        line,
  ].join('\n');
}
