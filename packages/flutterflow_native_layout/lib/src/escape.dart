/// Escaping text for the Swift, Kotlin and Android XML a widget generates.
/// One pass over the characters with a table, so each language's rules are
/// in one place.
library;

/// [value] with each character that [table] names replaced by its entry.
String escapeEach(String value, Map<String, String> table) {
  final out = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    out.write(table[char] ?? char);
  }
  return out.toString();
}

/// [value] as part of a Swift or Kotlin identifier or an Android resource
/// name: letters, digits and `_`, anything else as `_`.
String identifierPart(String value) {
  final out = StringBuffer();
  for (final rune in value.runes) {
    final ok =
        (rune >= 0x30 && rune <= 0x39) ||
        (rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A) ||
        rune == 0x5F;
    out.write(ok ? String.fromCharCode(rune) : '_');
  }
  return out.toString();
}

/// Inside a Swift string literal.
const kSwiftStringEscapes = {r'\': r'\\', '"': r'\"', '\r': r'\r', '\n': r'\n'};

/// Inside a Kotlin string literal (`$` starts a template there).
const kKotlinStringEscapes = {
  r'\': r'\\',
  '"': r'\"',
  r'$': r'\$',
  '\r': r'\r',
  '\n': r'\n',
};

/// An Android string in an XML attribute: the XML entities, then the
/// characters Android's string parsing treats specially. A carriage return
/// is written as `\u000D`: left raw, the XML parser turns it into a space.
const kAndroidXmlAttributeEscapes = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  r'\': r'\\',
  "'": r"\'",
  '@': r'\@',
  '?': r'\?',
  '\r': r'\u000D',
  '\n': r'\n',
};

/// An Android string resource's text.
const kAndroidXmlTextEscapes = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  r'\': r'\\',
  '"': r'\"',
  "'": r"\'",
  '@': r'\@',
  '?': r'\?',
  '\r': r'\u000D',
  '\n': r'\n',
};
