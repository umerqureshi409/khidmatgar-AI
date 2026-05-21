import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Enhanced AI Thinking indicator with rotating agent status messages
/// and a smooth animated multi-dot pulse.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotateController;

  // Cycle through these messages to show which agent is "thinking"
  static const List<_AgentStatus> _statuses = [
    _AgentStatus('ZARA', Icons.translate_rounded, 'Parsing your request...', AppTheme.secondaryNeon),
    _AgentStatus('KHOJI', Icons.radar_rounded, 'Searching providers...', AppTheme.primaryNeon),
    _AgentStatus('MUKHTAR', Icons.task_alt_rounded, 'Preparing booking...', AppTheme.goldAccent),
    _AgentStatus('YAKEEN', Icons.schedule_rounded, 'Scheduling follow-up...', Color(0xFF9C27B0)),
  ];

  int _statusIndex = 0;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Cycle the status label every 1.8 s to match the animation loop
    _rotateController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _statusIndex = (_statusIndex + 1) % _statuses.length;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _statuses[_statusIndex];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 60),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardNavy,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: status.color.withOpacity(0.25),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: status.color.withOpacity(0.08),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Agent label row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Spinning brain icon
                AnimatedBuilder(
                  animation: _rotateController,
                  builder: (context, child) => Transform.rotate(
                    angle: _rotateController.value * 2 * pi,
                    child: child,
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    color: status.color,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    status.agent,
                    key: ValueKey(status.agent),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: status.color,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Status message + dots
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: child,
                  ),
                  child: Text(
                    status.label,
                    key: ValueKey(status.label),
                    style: GoogleFonts.outfit(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _buildDot(0, status.color),
                const SizedBox(width: 4),
                _buildDot(200, status.color),
                const SizedBox(width: 4),
                _buildDot(400, status.color),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, duration: 300.ms);
  }

  Widget _buildDot(int delayMs, Color color) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .scaleXY(
          begin: 0.5,
          end: 1.2,
          duration: 600.ms,
          delay: delayMs.ms,
          curve: Curves.easeInOutSine,
        )
        .then()
        .scaleXY(
          begin: 1.2,
          end: 0.5,
          duration: 600.ms,
          curve: Curves.easeInOutSine,
        );
  }
}

class _AgentStatus {
  final String agent;
  final IconData icon;
  final String label;
  final Color color;

  const _AgentStatus(this.agent, this.icon, this.label, this.color);
}