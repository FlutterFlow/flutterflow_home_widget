/// A home screen widget fetching its own values, natively, on a schedule:
/// the request to make and where in the response each value is. Both
/// platforms' code is emitted from this plan.
library;

import 'package:flutterflow_home_widget/src/spec.dart';

/// The shortest interval: Android does not update a widget more often.
const kHomeWidgetMinRefreshMinutes = 30;

/// One step of a JSON path: an object's field or a list's item.
sealed class JsonStep {
  const JsonStep();
}

class JsonKey extends JsonStep {
  const JsonKey(this.name);
  final String name;
}

class JsonIndex extends JsonStep {
  const JsonIndex(this.index);
  final int index;
}

/// The steps of [path] (`$.a.b[0]`, `$['a']`), or null when it uses what a
/// widget cannot read natively: wildcards, filters, slices or `..`.
List<JsonStep>? parseJsonPath(String path) {
  final text = path.trim();
  if (!text.startsWith(r'$')) {
    return null;
  }
  final steps = <JsonStep>[];
  final step = RegExp(
    r'''\.([A-Za-z0-9_\-]+)|\[(\d+)\]|\['([^'\]]+)'\]|\["([^"\]]+)"\]''',
  );
  var at = 1;
  while (at < text.length) {
    final match = step.matchAsPrefix(text, at);
    if (match == null) {
      return null;
    }
    if (match[2] != null) {
      steps.add(JsonIndex(int.parse(match[2]!)));
    } else {
      steps.add(JsonKey(match[1] ?? match[3] ?? match[4]!));
    }
    at = match.end;
  }
  return steps;
}

/// One value the widget fetches: its parameter [key] and type, and where it
/// is in the response.
class FetchedValue {
  const FetchedValue(this.key, this.type, this.path);
  final String key;
  final HomeWidgetValueType type;
  final List<JsonStep> path;
}

/// The request and the values a widget fetches every [intervalMinutes].
class HomeWidgetRefreshPlan {
  const HomeWidgetRefreshPlan({
    required this.url,
    required this.headers,
    required this.intervalMinutes,
    required this.values,
  });

  /// May read the widget's values as `{key}`: each placed copy fills them in
  /// with its own values, so a widget a person picks a city for fetches that
  /// city's data.
  final String url;
  final Map<String, String> headers;
  final int intervalMinutes;
  final List<FetchedValue> values;

  /// The keys among [valueKeys] that [url] reads as `{key}`, in order.
  List<String> urlKeys(Iterable<String> valueKeys) => [
    for (final key in valueKeys)
      if (url.contains('{$key}')) key,
  ];
}
