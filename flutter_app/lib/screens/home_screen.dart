import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../services/auth_service.dart';
import '../services/functions_service.dart';
import 'upload_screen.dart';
import 'results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _audits = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final audits = await context.read<FunctionsService>().listAudits();
      if (mounted) setState(() { _audits = audits; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _scoreColor(double s) {
    if (s >= 80) return const Color(0xFF1D9E75);
    if (s >= 60) return const Color(0xFFBA7517);
    return const Color(0xFFA32D2D);
  }

  String _scoreLabel(double s) {
    if (s >= 80) return 'Fair';
    if (s >= 60) return 'Moderate';
    return 'Biased';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.balance, color: t.colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          const Text('FairScan'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [t.colorScheme.primaryContainer, t.colorScheme.secondaryContainer],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Hi ${user?.displayName?.split(' ').first ?? 'there'} 👋',
                  style: t.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload any AI decision dataset to check for bias.',
                  style: t.textTheme.bodyMedium,
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // New audit button
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadScreen()),
              ).then((_) => _load()),
              icon: const Icon(Icons.upload_file),
              label: const Text('Start New Fairness Audit'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),

            Text('Past audits', style: t.textTheme.titleMedium),
            const SizedBox(height: 8),

            if (_loading)
              ..._shimmerCards()
            else if (_error != null)
              _errorCard(_error!)
            else if (_audits.isEmpty)
              _emptyState()
            else
              ..._audits.map((a) {
                final score = (a['overall_fairness_score'] as num).toDouble();
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _scoreColor(score).withOpacity(0.15),
                      child: Text(
                        score.toStringAsFixed(0),
                        style: TextStyle(
                          color: _scoreColor(score),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Text(
                      (a['domain'] as String).toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      (a['created_at'] as String).substring(0, 10),
                    ),
                    trailing: Chip(
                      label: Text(_scoreLabel(score)),
                      backgroundColor: _scoreColor(score).withOpacity(0.1),
                      labelStyle: TextStyle(color: _scoreColor(score), fontSize: 12),
                      side: BorderSide.none,
                    ),
                    onTap: () async {
                      final full = await context.read<FunctionsService>()
                          .getAudit(a['audit_id'] as String);
                      if (context.mounted) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ResultsScreen(data: full),
                        ));
                      }
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  List<Widget> _shimmerCards() => List.generate(3, (_) =>
    Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Card(child: const ListTile(
        leading: CircleAvatar(),
        title: Text('          '),
        subtitle: Text('     '),
      )),
    ),
  );

  Widget _emptyState() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Column(children: [
      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
      SizedBox(height: 12),
      Text('No audits yet', style: TextStyle(color: Colors.grey)),
      Text('Start your first audit above', style: TextStyle(color: Colors.grey, fontSize: 12)),
    ]),
  );

  Widget _errorCard(String e) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: const Icon(Icons.error_outline),
      title: const Text('Could not load audits'),
      subtitle: Text(e, style: const TextStyle(fontSize: 12)),
      trailing: TextButton(onPressed: _load, child: const Text('Retry')),
    ),
  );
}
