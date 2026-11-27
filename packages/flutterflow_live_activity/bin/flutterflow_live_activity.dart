// Command line: validate a Live Activity spec (JSON), generate its files, or
// apply it to a Flutter app.
//
//   dart run flutterflow_live_activity validate live_activities.json
//   dart run flutterflow_live_activity generate live_activities.json out/
//   dart run flutterflow_live_activity apply live_activities.json path/to/app
import 'dart:convert';
import 'dart:io';

import 'package:flutterflow_live_activity/flutterflow_live_activity.dart';
import 'package:flutterflow_live_activity/io.dart';

const _usage = '''
Usage: flutterflow_live_activity <command> <spec.json> [<dir>]

  validate <spec.json>          Print every problem with the spec.
  generate <spec.json> <dir>    Write the generated files under <dir>.
  apply <spec.json> <app dir>   Add the Live Activities to a flutter create
                                app: files, pubspec, Xcode target,
                                Info.plist, entitlements.

generate and apply refuse a spec with problems; warnings do not stop them.''';

void main(List<String> args) {
  if (args.length < 2) {
    _fail(_usage, code: 64);
  }
  final command = args[0];
  final needsDir = command == 'generate' || command == 'apply';
  if (!{'validate', 'generate', 'apply'}.contains(command) ||
      (needsDir && args.length < 3)) {
    _fail(_usage, code: 64);
  }
  final LiveActivityApp app;
  try {
    final json = jsonDecode(File(args[1]).readAsStringSync());
    if (json is! Map<String, Object?>) {
      _fail('${args[1]}: expected a JSON object.');
    }
    app = liveActivityAppFromJson(json);
  } on FileSystemException catch (e) {
    _fail('${args[1]}: ${e.message}');
  } on FormatException catch (e) {
    _fail('${args[1]}: not JSON: ${e.message}');
  } on LiveActivityJsonException catch (e) {
    _fail('${args[1]}: ${e.path}: ${e.message}');
  }
  final problems = validateLiveActivityApp(app);
  for (final problem in problems) {
    stderr.writeln(problem);
  }
  final errors = problems.where((p) => !p.warning).length;
  if (errors > 0) {
    _fail('$errors problem${errors == 1 ? '' : 's'}.');
  }
  switch (command) {
    case 'validate':
      stdout.writeln(
        '${app.activities.length} activities, no problems'
        '${problems.isEmpty ? '' : ' (${problems.length} warnings)'}.',
      );
    case 'generate':
      final files = {
        ...generateLiveActivityFiles(app),
        ...liveActivityTypedApiFiles(app),
      };
      for (final MapEntry(:key, :value) in files.entries) {
        final file = File('${args[2]}/$key');
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(value);
      }
      stdout.writeln('Wrote ${files.length} files under ${args[2]}.');
    case 'apply':
      try {
        final written = applyLiveActivities(
          args[2],
          app,
          onWarning: (warning) => stderr.writeln('Warning: $warning'),
        );
        stdout.writeln('Updated ${written.length} files in ${args[2]}.');
      } on LiveActivityProjectException catch (e) {
        _fail(e.message);
      }
  }
}

Never _fail(String message, {int code = 1}) {
  stderr.writeln(message);
  exit(code);
}
