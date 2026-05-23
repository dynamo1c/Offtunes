import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../services/feedback_service.dart';

class HwButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool isPrimary;
  final Widget? icon;

  const HwButton({
    super.key,
    required this.text,
    required this.onTap,
    this.isPrimary = false,
    this.icon,
  });

  @override
  State<HwButton> createState() => _HwButtonState();
}

class _HwButtonState extends State<HwButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        if (widget.isPrimary) {
          FeedbackService.instance.clickPrimary();
        } else {
          FeedbackService.instance.clickSoft();
        }
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isPressed ? 2.0 : 0.0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _isPressed
              ? (widget.isPrimary ? AppColors.mauve : AppColors.rose)
              : (widget.isPrimary ? AppColors.rose : AppColors.surfaceRaised),
          border: Border(
            top: BorderSide(
              color: widget.isPrimary ? AppColors.mauve : AppColors.pink,
              width: 1.5,
            ),
            left: BorderSide(
              color: widget.isPrimary ? AppColors.mauve : AppColors.pink,
              width: 1.5,
            ),
            right: BorderSide(
              color: widget.isPrimary ? AppColors.mauve : AppColors.pink,
              width: 1.5,
            ),
            bottom: BorderSide(
              color: widget.isPrimary ? AppColors.mauve : AppColors.pink,
              width: _isPressed ? 1.5 : 3.5,
            ),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              widget.icon!,
              const SizedBox(width: 6),
            ],
            Text(
              widget.text.toUpperCase(),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _isPressed || widget.isPrimary ? AppColors.bg : AppColors.mauve,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
