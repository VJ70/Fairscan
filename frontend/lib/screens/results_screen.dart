import 'package:flutter/material.dart';
import '../models/audit_result.dart';

class ResultsScreen extends StatelessWidget {
  final AuditResult result;
  const ResultsScreen({super.key, required this.result});

  Color _scoreColor(double score) {
    if (score >= 80) return const Color(0xFF1D9E75);
    if (score >= 60) return const Color(0xFFBA7517);
    return const Color(0xFFA32D2D);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = result.overallFairnessScore;

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Results')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Score card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: _scoreColor(score).withOpacity(0.15),
                    child: Text(
                      score.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _scoreColor(score),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.biasDetected ? 'Bias Detected' : 'Looks Fair',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          result.biasDetected
                              ? 'Affected: ${result.affectedGroups.join(', ')}'
                              : 'No significant bias found',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Metrics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fairness Metrics', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _MetricRow('Demographic parity diff', result.metrics.demographicParityDifference,
                      ideal: 0, warnAbove: 0.1),
                  _MetricRow('Disparate impact ratio', result.metrics.disparateImpactRatio,
                      ideal: 1.0, warnBelow: 0.8),
                  _MetricRow('Equalized odds diff', result.metrics.equalizedOddsDifference,
                      ideal: 0, warnAbove: 0.1),
                  const Divider(height: 24),
                  Text('Selection rates by group', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  ...result.metrics.selectionRateByGroup.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(e.key, style: theme.textTheme.bodySmall)),
                            SizedBox(
                              width: 160,
                              child: LinearProgressIndicator(
                                value: e.value,
                                backgroundColor: theme.colorScheme.surfaceVariant,
                                color: _scoreColor(e.value * 100),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${(e.value * 100).toStringAsFixed(1)}%',
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Gemini report
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 18),
                      const SizedBox(width: 8),
                      Text('AI Analysis', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(result.geminiReport, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Remediation
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recommended Actions', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ...result.remediationSteps.map((step) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text('${step.priority}',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
                        ),
                        title: Text(step.action),
                        subtitle: Text(step.expectedImpact),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legal refs
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Legal References', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...result.legalReferences.map((ref) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontSize: 16)),
                            Expanded(child: Text(ref, style: theme.textTheme.bodySmall)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final double value;
  final double ideal;
  final double? warnAbove;
  final double? warnBelow;

  const _MetricRow(this.label, this.value,
      {required this.ideal, this.warnAbove, this.warnBelow});

  bool get isGood {
    if (warnAbove != null) return value <= warnAbove!;
    if (warnBelow != null) return value >= warnBelow!;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(
            value.toStringAsFixed(3),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isGood ? const Color(0xFF1D9E75) : const Color(0xFFA32D2D),
            ),
          ),
        ],
      ),
    );
  }
}
