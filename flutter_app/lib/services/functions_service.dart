import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class FunctionsService {
  final _fn = FirebaseFunctions.instanceFor(region: 'us-central1');
  final _storage = FirebaseStorage.instance;

  Future<String> uploadCsv(File file) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final name = '${DateTime.now().millisecondsSinceEpoch}.csv';
    final path = 'uploads/$uid/$name';
    await _storage.ref(path).putFile(file);
    return path;
  }

  Future<Map<String, dynamic>> previewCsv(String storagePath) async {
    final r = await _fn.httpsCallable('previewCsv').call({'storage_path': storagePath});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> runAudit({
    required String storagePath,
    required String domain,
    required String targetColumn,
    required String sensitiveColumn,
  }) async {
    final r = await _fn.httpsCallable('runAudit',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 300)),
    ).call({
      'storage_path': storagePath,
      'domain': domain,
      'target_column': targetColumn,
      'sensitive_column': sensitiveColumn,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<Map<String, dynamic>>> listAudits() async {
    final r = await _fn.httpsCallable('listAudits').call({});
    final data = r.data as Map;
    return List<Map<String, dynamic>>.from(
      (data['audits'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<Map<String, dynamic>> getAudit(String auditId) async {
    final r = await _fn.httpsCallable('getAudit').call({'audit_id': auditId});
    return Map<String, dynamic>.from(r.data as Map);
  }
}
