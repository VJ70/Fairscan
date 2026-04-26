import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/audit_result.dart';
import 'upload_screen.dart';
import 'results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = ApiService();
  List<AuditSummary> _audits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAudits();
  }

  Future<void> _loadAudits() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    try {
      final audits = await _apiService.listAudits(user.uid);
      if (mounted) setState(() { _audits = audits; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _scoreColor(double score) {
    if (score >= 80) return const Color(0xFF1D9E75);
    if (score >= 60) return const Color(0xFFBA7517);
    return const Color(0xFFA32D2D);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FairScan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAudits,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome card
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${user?.displayName?.split(' ').first ?? 'there'}',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Detect bias in your AI systems. Upload a CSV to start.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Start new audit button
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadScreen()),
              ).then((_) => _loadAudits()),
              icon: const Icon(Icons.upload_file),
              label: const Text('New Fairness Audit'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),

            Text('Past audits', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_audits.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No audits yet.\nStart your first audit above.', textAlign: TextAlign.center),
                ),
              )
            else
              ..._audits.map((audit) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _scoreColor(audit.overallFairnessScore).withOpacity(0.15),
                        child: Text(
                          audit.overallFairnessScore.toStringAsFixed(0),
                          style: TextStyle(
                            color: _scoreColor(audit.overallFairnessScore),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      title: Text(audit.domain.toUpperCase()),
                      subtitle: Text(audit.createdAt.substring(0, 10)),
                      trailing: audit.biasDetected
                          ? const Chip(label: Text('Bias found'))
                          : const Chip(label: Text('Fair')),
                      onTap: () async {
                        final full = await _apiService.getAudit(
                          audit.auditId,
                          user!.uid,
                        );
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResultsScreen(result: full),
                            ),
                          );
                        }
                      },
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
