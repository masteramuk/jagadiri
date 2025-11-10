// lib/utils/string_utils.dart

class StringUtils {
  /// Removes Unicode Variation Selector-16 (U+FE0F) from a string.
  /// This character is often used to force an emoji presentation,
  /// but can cause rendering issues if the font or system doesn't support it correctly.
  static String removeEmojiVariationSelectors(String text) {
    return text.replaceAll('\u{FE0F}', '');
  }
}
