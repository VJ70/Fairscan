import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/audit_result.dart';

class ApiService {
  static const String _baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080/api/v1');

  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
    ));

    // Attach Firebase ID token to every request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken();
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  /// Detect columns in a CSV file before full analysis
  Future<Map<String, dynamic>> detectColumns(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.get('/detect-columns', data: formData);
    return response.data as Map<String, dynamic>;
  }

  /// Run full bias audit
  Future<AuditResult> runAudit({
    required String filePath,
    required String domain,
    required String targetColumn,
    required String sensitiveColumn,
    required String userId,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'domain': domain,
      'target_column': targetColumn,
      'sensitive_column': sensitiveColumn,
      'user_id': userId,
    });

    final response = await _dio.post('/audit', data: formData);
    return AuditResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// List past audits for a user
  Future<List<AuditSummary>> listAudits(String userId) async {
    final response = await _dio.get('/audits', queryParameters: {'user_id': userId});
    return (response.data as List)
        .map((e) => AuditSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get a specific audit by ID
  Future<AuditResult> getAudit(String auditId, String userId) async {
    final response = await _dio.get(
      '/audit/$auditId',
      queryParameters: {'user_id': userId},
    );
    return AuditResult.fromJson(response.data as Map<String, dynamic>);
  }
}
