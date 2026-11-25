import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';
import 'package:test/test.dart';

void main() {
  test('identifierPart keeps letters, digits and _, anything else as _', () {
    expect(identifierPart('Text_1'), 'Text_1');
    expect(identifierPart('my-widget key'), 'my_widget_key');
    expect(identifierPart('caf\u00e9'), 'caf_');
  });

  group('a carriage return', () {
    test('is an escape in Swift and Kotlin strings', () {
      expect(swiftString('a\r\nb'), r'"a\r\nb"');
      expect(kotlinString('a\r\nb'), r'"a\r\nb"');
      expect(escapeEach('\r', kKotlinStringEscapes), r'\r');
    });

    test('is a character reference in Android XML, not a raw byte', () {
      expect(escapeEach('a\rb', kAndroidXmlAttributeEscapes), r'a\u000Db');
      expect(escapeEach('a\rb', kAndroidXmlTextEscapes), r'a\u000Db');
      for (final table in [
        kSwiftStringEscapes,
        kKotlinStringEscapes,
        kAndroidXmlAttributeEscapes,
        kAndroidXmlTextEscapes,
      ]) {
        expect(escapeEach('x\ry', table), isNot(contains('\r')));
      }
    });

    test('in a text leaves no raw byte in the layout or its binder', () {
      final model = NativeLayoutModel(
        LayoutFlex('Column_1', horizontal: false)
          ..items.addAll([
            LayoutTextNode('Text_1', const LayoutStaticText('one\r\ntwo')),
            LayoutTextNode('Text_2', const LayoutStaticText('three\rfour'))
              ..underline = true,
            LayoutTextNode(
              'Text_3',
              const LayoutParamText('p_note', LayoutValueType.string),
            ),
          ]),
        const [],
      );
      final android = remoteViewsLayout(
        't',
        model,
        defaults: const {'p_note': 'five\r\nsix'},
      );
      expect(android.xml, isNot(contains('\r')));
      expect(android.binder, isNot(contains('\r')));
      expect(android.xml, contains(r'android:text="one\u000D\ntwo"'));
      expect(android.binder, contains(r'"three\rfour"'));
      expect(swiftLayoutView('V', model), isNot(contains('\r')));
    });
  });

  test('XML attributes and text escape what XML and Android treat '
      'specially', () {
    expect(
      escapeEach('<a & "b"> \'c\' @d ?e \\', kAndroidXmlAttributeEscapes),
      isNot(contains('<')),
    );
    expect(escapeEach('a & b', kAndroidXmlTextEscapes), 'a &amp; b');
  });
}
