import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: t.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.balance, color: t.colorScheme.primary, size: 34),
              ),
              const SizedBox(height: 28),
              Text('FairScan', style: t.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                'AI Fairness Auditor\nDetect bias in hiring, lending & healthcare AI.\nBuilt for India.',
                style: t.textTheme.bodyLarge?.copyWith(
                  color: t.colorScheme.onSurfaceVariant, height: 1.6,
                ),
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: () => context.read<AuthService>().signInWithGoogle(),
                icon: const Icon(Icons.login),
                label: const Text('Continue with Google'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                _SdgChip('SDG 10'), const SizedBox(width: 8),
                _SdgChip('SDG 16'), const SizedBox(width: 8),
                _SdgChip('SDG 8'),
              ]),
              const SizedBox(height: 12),
              Text(
                'Google Solution Challenge 2026\nBuilt with Project IDX + Firebase + Gemini',
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SdgChip extends StatelessWidget {
  final String label;
  const _SdgChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: TextStyle(
      fontSize: 12, fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.primary,
    )),
  );
}
