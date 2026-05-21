import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/agent_trace_model.dart';
import '../theme/app_theme.dart';

class AgentTracePanel extends StatelessWidget {
  final AgentTrace trace;
  final bool isExpanded;
  final VoidCallback onToggle;
  final int? latencyMs;

  const AgentTracePanel({
    super.key,
    required this.trace,
    required this.isExpanded,
    required this.onToggle,
    this.latencyMs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle bar — always visible
        GestureDetector(
          onTap: onToggle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardNavy,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.goldAccent.withOpacity(isExpanded ? 0.5 : 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.hub_rounded,
                    color: AppTheme.goldAccent, size: 16)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .shimmer(duration: 2.seconds, color: AppTheme.goldAccent),
                const SizedBox(width: 8),
                Text('LIVE AGENT BRAIN',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.goldAccent,
                        letterSpacing: 2)),
                const Spacer(),
                if (latencyMs != null)
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNeon.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${latencyMs}ms',
                        style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: AppTheme.primaryNeon,
                            fontWeight: FontWeight.w600)),
                  ),
                Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: AppTheme.goldAccent,
                    size: 18),
              ],
            ),
          ),
        ),

        // Expandable content
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState:
              isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            margin:
                const EdgeInsets.only(left: 16, right: 16, bottom: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardNavy,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.goldAccent.withOpacity(0.25), width: 1.2),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAgentStep('ZARA', trace.zaraTrace,
                      Icons.translate_rounded, AppTheme.secondaryNeon),
                  _buildAgentStep('KHOJI', trace.khojiTrace,
                      Icons.radar_rounded, AppTheme.primaryNeon),
                  _buildAgentStep('MUKHTAR', trace.mukhtarTrace,
                      Icons.task_alt_rounded, AppTheme.goldAccent),
                  _buildAgentStep('YAKEEN', trace.yakeenTrace,
                      Icons.schedule_rounded, const Color(0xFF9C27B0)),
                  _buildAgentStep('HIFAZAT', trace.hifazatTrace,
                      Icons.shield_rounded, Colors.redAccent),
                  if (trace.beforeState != null && trace.afterState != null)
                    _buildStateTransition(),
                ],
              ),
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildAgentStep(
      String name, String? traceText, IconData icon, Color color) {
    if (traceText == null || traceText.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final isActive = trace.activeAgent == name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(isActive ? 0.25 : 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: color.withOpacity(isActive ? 0.7 : 0.3), width: 1.2),
              boxShadow: isActive
                  ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)]
                  : [],
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                            letterSpacing: 1.5)),
                    if (isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true))
                          .fade(begin: 0.3, end: 1.0, duration: 800.ms),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  traceText,
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppTheme.textPrimary.withOpacity(0.85),
                      height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 350.ms, delay: 50.ms),
    );
  }

  Widget _buildStateTransition() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STATE TRANSITION',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  color: AppTheme.textSecondary,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _buildStateCol('BEFORE', trace.beforeState!)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward_rounded,
                    color: AppTheme.primaryNeon, size: 18),
              ),
              Expanded(
                  child: _buildStateCol('AFTER', trace.afterState!)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStateCol(String title, Map<String, dynamic> state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.outfit(
                fontSize: 10,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...state.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Icon(Icons.circle,
                      size: 5,
                      color: title == 'AFTER'
                          ? AppTheme.primaryNeon
                          : AppTheme.textSecondary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text('${e.key}: ${e.value}',
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: title == 'AFTER'
                                ? AppTheme.primaryNeon
                                : AppTheme.textPrimary,
                            fontWeight: title == 'AFTER'
                                ? FontWeight.w600
                                : FontWeight.normal),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
