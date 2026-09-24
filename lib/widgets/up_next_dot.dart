import 'package:flutter/material.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';

/// Little red notification dot marking the immediate next task to do.
class UpNextDot extends StatelessWidget {
  final double size;
  const UpNextDot({super.key, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppLocalizations.of(context)!.upNext,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF43F5E),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Color(0xFFF43F5E), blurRadius: 6, spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}
