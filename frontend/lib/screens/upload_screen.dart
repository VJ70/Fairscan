import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'results_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _apiService = ApiService();
  PlatformFile? _selectedFile;
  Map<String, dynamic>? _detectedColumns;
  String? _selectedDomain;
  String? _targetColumn;
  String? _sensitiveColumn;
  bool _isLoading = false;
  String? _error;

  final _domains = ['hiring', 'lending', 'healthcare', 'other'];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) return;

    setState(() { _selectedFile = result.files.first; _isLoading = true; _error = null; });

    try {
      final detected = await _apiService.detectColumns(_selectedFile!.path!);
      setState(() { _detectedColumns = detected; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Could not read file: $e'; _isLoading = false; });
    }
  }

  Future<void> _runAudit() async {
    if (_selectedFile == null || _selectedDomain == null ||
        _targetColumn == null || _sensitiveColumn == null) return;

    setState(() { _isLoading = true; _error = null; });

    try {
      final user = context.read<AuthService>().currentUser!;
      final result = await _apiService.runAudit(
        filePath: _selectedFile!.path!,
        domain: _selectedDomain!,
        targetColumn: _targetColumn!,
        sensitiveColumn: _sensitiveColumn!,
        userId: user.uid,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ResultsScreen(result: result)),
        );
      }
    } catch (e) {
      setState(() { _error = 'Audit failed: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cols = _detectedColumns?['all_columns'] as List? ?? [];
    final suggested = _detectedColumns?['suggested_sensitive_columns'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('New Audit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // File upload zone
          InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _selectedFile != null
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  width: _selectedFile != null ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _selectedFile != null ? Icons.check_circle : Icons.upload_file,
                      size: 36,
                      color: _selectedFile != null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFile?.name ?? 'Tap to upload CSV',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_detectedColumns != null)
                      Text(
                        '${_detectedColumns!['row_count']} rows · ${cols.length} columns',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_detectedColumns != null) ...[
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Domain'),
              items: _domains.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setState(() => _selectedDomain = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Outcome column (what the AI decided)'),
              items: cols.map((c) => DropdownMenuItem(value: c.toString(), child: Text(c.toString()))).toList(),
              onChanged: (v) => setState(() => _targetColumn = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Group to check fairness for',
                helperText: suggested.isNotEmpty ? 'Suggested: ${suggested.join(', ')}' : null,
              ),
              items: cols.map((c) => DropdownMenuItem(value: c.toString(), child: Text(c.toString()))).toList(),
              onChanged: (v) => setState(() => _sensitiveColumn = v),
              value: suggested.isNotEmpty ? suggested.first.toString() : null,
            ),
            const SizedBox(height: 24),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),

            FilledButton(
              onPressed: (_selectedDomain != null && _targetColumn != null && _sensitiveColumn != null)
                  ? _runAudit
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Run Fairness Audit'),
            ),
          ],
        ],
      ),
    );
  }
}
