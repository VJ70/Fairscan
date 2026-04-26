import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/functions_service.dart';
import 'results_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _file;
  String? _storagePath;
  Map<String, dynamic>? _preview;
  String? _domain;
  String? _targetCol;
  String? _sensitiveCol;
  bool _uploading = false;
  bool _auditing = false;
  String? _error;
  String _statusMsg = '';

  final _domains = [
    {'value': 'hiring', 'label': '💼 Hiring & Recruitment'},
    {'value': 'lending', 'label': '🏦 Loans & Credit'},
    {'value': 'healthcare', 'label': '🏥 Healthcare'},
    {'value': 'other', 'label': '🔧 Other'},
  ];

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.first.path!);
    setState(() { _uploading = true; _error = null; _statusMsg = 'Uploading CSV...'; });

    try {
      final fn = context.read<FunctionsService>();
      final path = await fn.uploadCsv(file);
      setState(() { _statusMsg = 'Detecting columns...'; });
      final preview = await fn.previewCsv(path);

      setState(() {
        _file = file;
        _storagePath = path;
        _preview = preview;
        _uploading = false;
        _statusMsg = '';
        // Auto-select suggested columns
        final sensitive = preview['suggested_sensitive'] as List? ?? [];
        final target = preview['suggested_target'] as List? ?? [];
        if (sensitive.isNotEmpty) _sensitiveCol = sensitive.first as String;
        if (target.isNotEmpty) _targetCol = target.first as String;
      });
    } catch (e) {
      setState(() { _error = 'Upload failed: $e'; _uploading = false; _statusMsg = ''; });
    }
  }

  Future<void> _runAudit() async {
    if (_storagePath == null || _domain == null || _targetCol == null || _sensitiveCol == null) return;
    setState(() { _auditing = true; _error = null; _statusMsg = 'Analysing bias patterns...'; });

    try {
      final result = await context.read<FunctionsService>().runAudit(
        storagePath:     _storagePath!,
        domain:          _domain!,
        targetColumn:    _targetCol!,
        sensitiveColumn: _sensitiveCol!,
      );
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ResultsScreen(data: result),
        ));
      }
    } catch (e) {
      setState(() { _error = 'Audit failed: $e'; _auditing = false; _statusMsg = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cols = List<String>.from(_preview?['all_columns'] as List? ?? []);

    return Scaffold(
      appBar: AppBar(title: const Text('New Audit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Upload zone
          GestureDetector(
            onTap: (_uploading || _auditing) ? null : _pickAndUpload,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _file != null
                      ? t.colorScheme.primary
                      : t.colorScheme.outline,
                  width: _file != null ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: _file != null
                    ? t.colorScheme.primaryContainer.withOpacity(0.3)
                    : null,
              ),
              child: Center(
                child: _uploading
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(_statusMsg, style: t.textTheme.bodySmall),
                      ])
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          _file != null ? Icons.check_circle : Icons.upload_file,
                          size: 40,
                          color: _file != null ? t.colorScheme.primary : t.colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _file != null
                              ? _file!.path.split('/').last
                              : 'Tap to upload CSV',
                          style: t.textTheme.bodyMedium,
                        ),
                        if (_preview != null)
                          Text(
                            '${_preview!['row_count']} rows · ${cols.length} columns',
                            style: t.textTheme.bodySmall,
                          ),
                      ]),
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_preview != null) ...[
            // Domain picker
            Text('What type of decisions?', style: t.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _domains.map((d) {
                final selected = _domain == d['value'];
                return FilterChip(
                  label: Text(d['label']!),
                  selected: selected,
                  onSelected: (_) => setState(() => _domain = d['value']),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Target column
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Outcome column (what the AI decided)',
                helperText: 'e.g. "hired", "approved" — must be 0 or 1',
                border: OutlineInputBorder(),
              ),
              value: _targetCol,
              items: cols.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _targetCol = v),
            ),
            const SizedBox(height: 12),

            // Sensitive column
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Group to check fairness for',
                helperText: _preview!['suggested_sensitive'] != null
                    ? 'Auto-detected: ${(_preview!['suggested_sensitive'] as List).join(', ')}'
                    : 'e.g. "gender", "caste", "income_group"',
                border: const OutlineInputBorder(),
              ),
              value: _sensitiveCol,
              items: cols.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _sensitiveCol = v),
            ),
            const SizedBox(height: 24),
          ],

          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: t.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: TextStyle(color: t.colorScheme.onErrorContainer)),
            ),

          if (_preview != null)
            FilledButton.icon(
              onPressed: (_auditing || _domain == null || _targetCol == null || _sensitiveCol == null)
                  ? null : _runAudit,
              icon: _auditing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.analytics),
              label: Text(_auditing ? _statusMsg : 'Run Fairness Audit'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
        ],
      ),
    );
  }
}
