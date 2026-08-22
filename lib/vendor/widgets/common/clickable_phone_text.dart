import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays free text with any phone numbers inside it highlighted and
/// actionable: tap to call, long-press to copy.
///
/// Order descriptions and notes are plain strings that frequently contain a
/// contact number typed inline ("اتصل على 01012345678 قبل التوصيل"). Rendered
/// as a bare Text those digits cannot be called or copied, forcing the vendor
/// to retype them by hand. Structured fields use [ClickablePhoneField]
/// instead; this is for numbers embedded in prose.
class ClickablePhoneText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? phoneStyle;

  const ClickablePhoneText({
    super.key,
    required this.text,
    this.style,
    this.phoneStyle,
  });

  // Matches 01234567890, 0123-456-7890, +201234567890 and similar.
  static final RegExp _phoneRegex = RegExp(
    r'(\+?\d{1,4}[-.\s]?)?\(?\d{1,4}\)?[-.\s]?\d{1,4}[-.\s]?\d{1,9}',
  );

  @override
  Widget build(BuildContext context) {
    // Theme-driven rather than a hardcoded black: RichText does not inherit
    // DefaultTextStyle the way Text does, so a fixed dark colour here would
    // vanish against the dark-mode surface.
    final scheme = Theme.of(context).colorScheme;
    final defaultStyle =
        style ?? TextStyle(fontSize: 14, color: scheme.onSurface);
    final defaultPhoneStyle = phoneStyle ??
        TextStyle(
          fontSize: 14,
          color: scheme.primary,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        );

    return RichText(
      text: TextSpan(
        children: _buildTextSpans(context, defaultStyle, defaultPhoneStyle),
      ),
    );
  }

  List<TextSpan> _buildTextSpans(
    BuildContext context,
    TextStyle normalStyle,
    TextStyle phoneStyle,
  ) {
    final spans = <TextSpan>[];
    final matches = _phoneRegex.allMatches(text).toList();

    if (matches.isEmpty) {
      return [TextSpan(text: text, style: normalStyle)];
    }

    var lastEnd = 0;
    for (final match in matches) {
      final phoneNumber = match.group(0)!;
      // Prices, quantities and order numbers also match the regex, so require
      // enough digits to be a real number before making it tappable.
      final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length < 7) continue;

      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: normalStyle,
        ));
      }

      spans.add(TextSpan(
        text: phoneNumber,
        style: phoneStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () => _callPhoneNumber(phoneNumber),
        onEnter: null,
        onExit: null,
      ));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: normalStyle));
    }

    return spans.isEmpty ? [TextSpan(text: text, style: normalStyle)] : spans;
  }

  Future<void> _callPhoneNumber(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

/// Copies [phoneNumber] to the clipboard and confirms with a snackbar.
void copyPhoneNumber(BuildContext context, String phoneNumber) {
  Clipboard.setData(ClipboardData(text: phoneNumber));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('تم نسخ الرقم')),
  );
}
