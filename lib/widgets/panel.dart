import 'package:flutter/material.dart';
import '../core/constants.dart';

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const Panel({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.pink, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }
}
