class BiasMetrics {
  final double demographicParityDifference;
  final double disparateImpactRatio;
  final double equalizedOddsDifference;
  final Map<String, double> selectionRateByGroup;
  final Map<String, double> falsePositiveRateByGroup;

  BiasMetrics({
    required this.demographicParityDifference,
    required this.disparateImpactRatio,
    required this.equalizedOddsDifference,
    required this.selectionRateByGroup,
    required this.falsePositiveRateByGroup,
  });

  factory BiasMetrics.fromJson(Map<String, dynamic> j) => BiasMetrics(
        demographicParityDifference: (j['demographic_parity_difference'] as num).toDouble(),
        disparateImpactRatio: (j['disparate_impact_ratio'] as num).toDouble(),
        equalizedOddsDifference: (j['equalized_odds_difference'] as num).toDouble(),
        selectionRateByGroup: Map<String, double>.from(
            (j['selection_rate_by_group'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble()))),
        falsePositiveRateByGroup: Map<String, double>.from(
            (j['false_positive_rate_by_group'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble()))),
      );
}

class RemediationStep {
  final int priority;
  final String action;
  final String description;
  final String technique;
  final String expectedImpact;

  RemediationStep({
    required this.priority,
    required this.action,
    required this.description,
    required this.technique,
    required this.expectedImpact,
  });

  factory RemediationStep.fromJson(Map<String, dynamic> j) => RemediationStep(
        priority: j['priority'] as int,
        action: j['action'] as String,
        description: j['description'] as String,
        technique: j['technique'] as String,
        expectedImpact: j['expected_impact'] as String,
      );
}

class AuditResult {
  final String auditId;
  final String userId;
  final String domain;
  final double overallFairnessScore;
  final bool biasDetected;
  final List<String> affectedGroups;
  final BiasMetrics metrics;
  final String geminiReport;
  final List<RemediationStep> remediationSteps;
  final List<String> legalReferences;
  final String createdAt;
  final String? pdfUrl;

  AuditResult({
    required this.auditId,
    required this.userId,
    required this.domain,
    required this.overallFairnessScore,
    required this.biasDetected,
    required this.affectedGroups,
    required this.metrics,
    required this.geminiReport,
    required this.remediationSteps,
    required this.legalReferences,
    required this.createdAt,
    this.pdfUrl,
  });

  factory AuditResult.fromJson(Map<String, dynamic> j) => AuditResult(
        auditId: j['audit_id'] as String,
        userId: j['user_id'] as String,
        domain: j['domain'] as String,
        overallFairnessScore: (j['overall_fairness_score'] as num).toDouble(),
        biasDetected: j['bias_detected'] as bool,
        affectedGroups: List<String>.from(j['affected_groups'] as List),
        metrics: BiasMetrics.fromJson(j['metrics'] as Map<String, dynamic>),
        geminiReport: j['gemini_report'] as String,
        remediationSteps: (j['remediation_steps'] as List)
            .map((e) => RemediationStep.fromJson(e as Map<String, dynamic>))
            .toList(),
        legalReferences: List<String>.from(j['legal_references'] as List),
        createdAt: j['created_at'] as String,
        pdfUrl: j['pdf_url'] as String?,
      );
}

class AuditSummary {
  final String auditId;
  final String domain;
  final double overallFairnessScore;
  final bool biasDetected;
  final String createdAt;

  AuditSummary({
    required this.auditId,
    required this.domain,
    required this.overallFairnessScore,
    required this.biasDetected,
    required this.createdAt,
  });

  factory AuditSummary.fromJson(Map<String, dynamic> j) => AuditSummary(
        auditId: j['audit_id'] as String,
        domain: j['domain'] as String,
        overallFairnessScore: (j['overall_fairness_score'] as num).toDouble(),
        biasDetected: j['bias_detected'] as bool,
        createdAt: j['created_at'] as String,
      );
}
