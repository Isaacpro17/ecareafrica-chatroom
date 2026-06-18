import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class OnlineDot extends StatelessWidget {
  final bool isOnline;
  final double size;

  const OnlineDot({super.key, required this.isOnline, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOnline ? AppColors.online : AppColors.offline,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 1.5),
      ),
    );
  }
}
