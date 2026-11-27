/// The JSON form of a layout, for a spec that holds layouts: reading and
/// writing a [NativeLayoutModel] as JSON ([nativeLayoutFromJson],
/// [nativeLayoutToJson]) and the reader a spec reads its own JSON with
/// ([SpecJsonReader], [NativeLayoutJsonException]).
///
/// Kept apart from the main library, which has the layout model and its
/// emitters, so that a tool that draws layouts does not take on the JSON API.
library;

import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';

export 'src/layout/layout_json.dart';
