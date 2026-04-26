import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ResultsScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const ResultsScreen({super.key, required this.data});

  Color _scoreColor(double s) {
    if (s >= 80) return const Color(0xFF1D9E75);
    if (s >= 60) return const Color(0xFFBA7517);
    return const Color(0xFFA32D2D);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final score = (data['overall_fairness_score'] as num).toDouble();
    final biased = data['bias_detected'] as bool;
    final metrics = data['metrics'] as Map<String, dynamic>;
    final rates = Map<String, double>.from(
      (metrics['selection_rate_by_group'] as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toDouble())),
    );
    final affected = List<String>.from(data['affected_groups'] as List);
    final report = data['gemini_report'] as String;
    final steps = List<Map<String, dynamic>>.from(
      (data['remediation_steps'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final legalRefs = List<String>.from(data['legal_references'] as List);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Results')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Score hero
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Stack(alignment: Alignment.center, children: [
                  SizedBox(
                    width: 72, height: 72,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 7,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(_scoreColor(score)),
                    ),
                  ),
                  Text(
                    score.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: _scoreColor(score),
                    ),
                  ),
                ]),
                const SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      biased ? '⚠️ Bias Detected' : '✅ Looks Fair',
                      style: t.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      biased
                          ? 'Disadvantaged: ${affected.join(', ')}'
                          : 'No significant disparity found',
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Bar chart — selection rates
          if (rates.isNotEmpty) Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selection rates by group', style: t.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: BarChart(BarChartData(
                      barGroups: rates.entries.toList().asMap().entries.map((entry) {
                        final i = entry.key;
                        final e = entry.value;
                        return BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: e.value * 100,
                            color: _scoreColor(e.value * 100),
                            width: 24,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ]);
                      }).toList(),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10)),
                        )),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final keys = rates.keys.toList();
                            final idx = v.toInt();
                            if (idx >= 0 && idx < keys.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(keys[idx], style: const TextStyle(fontSize: 10)),
                              );
                            }
                            return const Text('');
                          },
                        )),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: 20,
                      ),
                      borderData: FlBorderData(show: false),
                    )),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Metrics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fairness Metrics', style: t.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _MetricTile(
                    'Demographic Parity Diff',
                    (metrics['demographic_parity_difference'] as num).toDouble(),
                    good: (metrics['demographic_parity_difference'] as num) <= 0.1,
                    hint: 'Ideal: 0  |  >0.1 is concerning',
                  ),
                  _MetricTile(
                    'Disparate Impact Ratio',
                    (metrics['disparate_impact_ratio'] as num).toDouble(),
                    good: (metrics['disparate_impact_ratio'] as num) >= 0.8,
                    hint: 'Ideal: 1.0  |  <0.8 = potential discrimination',
                  ),
                  _MetricTile(
                    'Equalized Odds Diff',
                    (metrics['equalized_odds_difference'] as num).toDouble(),
                    good: (metrics['equalized_odds_difference'] as num) <= 0.1,
                    hint: 'Ideal: 0',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Gemini report
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.auto_awesome, size: 18),
                    const SizedBox(width: 8),
                    Text('Gemini Analysis', style: t.textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 12),
                  Text(report, style: t.textTheme.bodyMedium?.copyWith(height: 1.7)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Remediation steps
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recommended Actions', style: t.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...steps.map((s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: t.colorScheme.primaryContainer,
                      child: Text('${s['priority']}',
                        style: TextStyle(fontSize: 12, color: t.colorScheme.primary)),
                    ),
                    title: Text(s['action'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(s['expected_impact'] as String,
                      style: const TextStyle(fontSize: 12)),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Legal refs
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Legal References (India)', style: t.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...legalRefs.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('• ', style: TextStyle(fontSize: 16)),
                      Expanded(child: Text(r, style: t.textTheme.bodySmall?.copyWith(height: 1.5))),
                    ]),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final double value;
  final bool good;
  final String hint;
  const _MetricTile(this.label, this.value, {required this.good, required this.hint});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(hint, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ])),
      Text(
        value.toStringAsFixed(3),
        style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 16,
          color: good ? const Color(0xFF1D9E75) : const Color(0xFFA32D2D),
        ),
      ),
    ]),
  );
}
