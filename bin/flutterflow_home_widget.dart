// Command line: validate a home widget spec (JSON), generate its files, or
// apply it to a Flutter app.
//
//   dart run flutterflow_home_widget validate widgets.json
//   dart run flutterflow_home_widget generate widgets.json out/
//   dart run flutterflow_home_widget apply widgets.json path/to/app
import 'dart:convert';
import 'dart:io';

import 'package:flutterflow_home_widget/flutterflow_home_widget.dart';
import 'package:flutterflow_home_widget/io.dart';

const _usage = '''
Usage: flutterflow_home_widget <command> <spec.json> [<dir>]

  validate <spec.json>          Print every problem with the spec.
  generate <spec.json> <dir>    Write the generated files under <dir>.
  apply <spec.json> <app dir>   Add the widgets to a flutter create app:
                                files, pubspec, Xcode target, Info.plist,
                                entitlements.

generate and apply refuse a spec with problems.''';

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
  final HomeWidgetApp app;
  try {
    final json = jsonDecode(File(args[1]).readAsStringSync());
    if (json is! Map<String, Object?>) {
      _fail('${args[1]}: expected a JSON object.');
    }
    app = homeWidgetAppFromJson(json);
  } on FileSystemException catch (e) {
    _fail('${args[1]}: ${e.message}');
  } on FormatException catch (e) {
    _fail('${args[1]}: not JSON: ${e.message}');
  } on HomeWidgetJsonException catch (e) {
    _fail('${args[1]}: ${e.path}: ${e.message}');
  }
  final problems = validateHomeWidgetApp(app);
  for (final problem in problems) {
    stderr.writeln(problem);
  }
  if (problems.isNotEmpty) {
    _fail('${problems.length} problem${problems.length == 1 ? '' : 's'}.');
  }
  switch (command) {
    case 'validate':
      stdout.writeln('${app.widgets.length} widgets, no problems.');
    case 'generate':
      final files = generateHomeWidgetFiles(app);
      for (final MapEntry(:key, :value) in files.entries) {
        final file = File('${args[2]}/$key');
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(value);
      }
      stdout.writeln('Wrote ${files.length} files under ${args[2]}.');
    case 'apply':
      try {
        final written = applyHomeWidgets(args[2], app);
        stdout.writeln('Updated ${written.length} files in ${args[2]}.');
      } on HomeWidgetProjectException catch (e) {
        _fail(e.message);
      }
  }
}

Never _fail(String message, {int code = 1}) {
  stderr.writeln(message);
  exit(code);
}
