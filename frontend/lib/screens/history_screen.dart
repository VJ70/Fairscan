import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Audit History')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history, size: 48, color: Color(0xFFD3D1C7)),
              const SizedBox(height: 16),
              Text(
                'No audits yet',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Run your first fairness audit to see results here.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF888780),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                ),
                onPressed: () => Navigator.pushNamed(context, '/upload'),
                child: const Text('Start Audit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
