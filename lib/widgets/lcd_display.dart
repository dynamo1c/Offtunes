import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';

class LcdDisplay extends StatelessWidget {
  final String text;
  final double fontSize;

  const LcdDisplay({super.key, required this.text, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.lcdBg,
        border: Border.all(color: Colors.black.withAlpha(13), width: 2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: GoogleFonts.shareTechMono(
          color: AppColors.lcd,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
