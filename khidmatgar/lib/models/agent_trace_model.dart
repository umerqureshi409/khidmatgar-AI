class AgentTrace {
  final String activeAgent;
  final String? zaraTrace;
  final String? khojiTrace;
  final String? mukhtarTrace;
  final String? yakeen;
  final String? yakeen_trace;
  final String? hifazatTrace;
  final Map<String, dynamic>? beforeState;
  final Map<String, dynamic>? afterState;

  AgentTrace({
    required this.activeAgent,
    this.zaraTrace,
    this.khojiTrace,
    this.mukhtarTrace,
    this.yakeen,
    this.yakeen_trace,
    this.hifazatTrace,
    this.beforeState,
    this.afterState,
  });

  factory AgentTrace.fromJson(Map<String, dynamic> json) {
    return AgentTrace(
      activeAgent: json['active_agent'] ?? 'Unknown',
      zaraTrace: json['zara_trace'],
      khojiTrace: json['khoji_trace'],
      mukhtarTrace: json['mukhtar_trace'],
      yakeen: json['yakeen_trace'],
      yakeen_trace: json['yakeen_trace'],
      hifazatTrace: json['hifazat_trace'],
      beforeState: json['before_state'] != null
          ? Map<String, dynamic>.from(json['before_state'])
          : null,
      afterState: json['after_state'] != null
          ? Map<String, dynamic>.from(json['after_state'])
          : null,
    );
  }

  bool get hasYakeen =>
      (yakeen != null && yakeen!.isNotEmpty) ||
      (yakeen_trace != null && yakeen_trace!.isNotEmpty);

  String? get yakeenTrace => yakeen_trace ?? yakeen;
}
