import 'package:flutterflow_live_activity/flutterflow_live_activity.dart';

const bundleId = 'com.example.rides';

/// A Lock Screen layout: a filled box around a column with a title, a bound
/// text, a countdown, a bar of the trip's progress, the driver's photo
/// ([photoSide] points square), the car's picture and an icon.
NativeLayoutModel lockLayout({LayoutTap? tap, double photoSide = 40}) {
  final column = LayoutFlex('Column_1', horizontal: false)
    ..items.addAll([
      LayoutTextNode('Text_1', const LayoutStaticText('Your ride')),
      LayoutTextNode(
        'Text_2',
        const LayoutParamText('v_driver', LayoutValueType.string),
      ),
      LayoutTextNode(
        'Text_3',
        const LayoutParamText('v_eta', LayoutValueType.dateTime),
      ),
      LayoutProgress(
        'Bar_1',
        circular: false,
        value: const LayoutFraction.param('v_done'),
      ),
      LayoutImage('Image_1', 'assets/images/driver.png', paramKey: 'v_photo')
        ..width = LayoutLength.points(photoSide)
        ..height = LayoutLength.points(photoSide),
      LayoutImage('Image_2', 'assets/images/car.png'),
      LayoutIcon('Icon_1', 0xe1d7),
    ]);
  final box =
      LayoutBox('Container_1')
        ..background = const LayoutPaint.fixed(
          LayoutColor(0xFFFFFFFF, 0xFF101213),
        )
        ..child = column;
  return NativeLayoutModel(box, const [], tap: tap);
}

/// An expanded island layout: a box filled with [fill] around a text.
NativeLayoutModel expandedLayout({int fill = 0xFF224466}) => NativeLayoutModel(
  LayoutBox('Container_9')
    ..background = LayoutPaint.fixed(LayoutColor.same(fill))
    ..child = LayoutTextNode(
      'Text_9',
      const LayoutParamText('v_driver', LayoutValueType.string),
    ),
  const [],
);

/// A layout for a compact side or the minimal island: an icon, or the
/// photo when [photo].
NativeLayoutModel compactLayout({bool photo = false}) => NativeLayoutModel(
  photo
      ? LayoutImage('Image_5', 'assets/images/driver.png', paramKey: 'v_photo')
      : LayoutIcon('Icon_5', 0xe531),
  const [],
);

/// The values of the ride card.
const rideValues = [
  LiveActivityValue(
    key: 'v_title',
    name: 'title',
    type: LiveActivityValueType.string,
    defaultValue: 'Your ride',
  ),
  LiveActivityValue(
    key: 'v_driver',
    name: 'driver',
    type: LiveActivityValueType.string,
    defaultValue: '',
  ),
  LiveActivityValue(
    key: 'v_done',
    name: 'done',
    type: LiveActivityValueType.double,
    defaultValue: '0.25',
  ),
  LiveActivityValue(
    key: 'v_eta',
    name: 'eta',
    type: LiveActivityValueType.dateTime,
    required: true,
  ),
  LiveActivityValue(
    key: 'v_accent',
    name: 'accent',
    type: LiveActivityValueType.color,
    defaultValue: '#FF39D2C0',
  ),
  LiveActivityValue(
    key: 'v_photo',
    name: 'photo',
    type: LiveActivityValueType.image,
    defaultValue: 'assets/images/driver.png',
  ),
];

/// A Custom card with [values] and a Lock Screen and an expanded island
/// layout (each a model of its own).
LiveActivityDefinition rideCard({
  String key = 'la_ride',
  List<LiveActivityValue> values = rideValues,
  Map<LiveActivitySurface, NativeLayoutModel>? surfaces,
  LiveActivityAndroid android = const LiveActivityAndroid(),
  Map<String, String>? androidDefaults,
}) => LiveActivityDefinition(
  key: key,
  name: 'Ride',
  template: LiveActivityTemplate.custom,
  values: values,
  surfaces:
      surfaces ??
      {
        LiveActivitySurface.lockScreen: lockLayout(),
        LiveActivitySurface.islandExpanded: expandedLayout(),
      },
  android: android,
  androidDefaults: androidDefaults,
);

/// A definition of fixed template [template].
LiveActivityDefinition fixedCard(
  LiveActivityTemplate template, {
  String key = 'la_order',
}) => LiveActivityDefinition(key: key, name: 'Order', template: template);

LiveActivityApp appWith(
  List<LiveActivityDefinition> activities, {
  String deviceFamily = '1',
  LiveActivityRoutes routes = const LiveActivityRoutes(scheme: 'rides'),
}) => LiveActivityApp(
  iosBundleId: bundleId,
  iosDeviceFamily: deviceFamily,
  routes: routes,
  activities: activities,
);

int count(String text, String part) => part.allMatches(text).length;
