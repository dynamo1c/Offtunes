import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../services/feedback_service.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.pink, width: 1.5)),
      ),
      child: Row(
        children: [
          _buildItem(0, 'LIB', PhosphorIconsRegular.musicNotesSimple),
          _buildItem(1, 'QUERY', PhosphorIconsRegular.magnifyingGlass),
          _buildItem(2, 'LOAD', PhosphorIconsRegular.downloadSimple),
          _buildItem(3, 'CFG', PhosphorIconsRegular.slidersHorizontal),
        ],
      ),
    );
  }

  Widget _buildItem(int index, String label, IconData icon) {
    final isActive = currentIndex == index;
    final color = isActive ? AppColors.rose : AppColors.textSoft;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FeedbackService.instance.navTap();
          onTap(index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.rose,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
