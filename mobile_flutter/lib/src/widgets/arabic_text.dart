import 'package:flutter/material.dart';

class ArabicText extends StatelessWidget {
  const ArabicText(
    this.data, {
    super.key,
    this.style,
    this.textAlign = TextAlign.right,
    this.maxLines,
    this.overflow,
  });

  final String data;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  static const _locale = Locale('ar');

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        data,
        locale: _locale,
        textDirection: TextDirection.rtl,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        style: style,
      ),
    );
  }
}
