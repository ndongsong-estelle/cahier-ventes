import 'dart:convert';

import 'package:dio/dio.dart';

import '../api/api_client.dart';

class BackupMeta {
  const BackupMeta({
    required this.id,
    required this.createdAt,
    required this.sha256,
  });
  final String id;
  final DateTime createdAt;
  final String sha256;
}

/// POST /backups, GET /backups/latest, GET /backups/{id}/file (docs/03).
abstract class BackupApi {
  Future<void> upload(List<int> gz, String sha256, Map<String, int> counts);
  Future<BackupMeta?> latest();
  Future<List<int>> download(String id);
}

class HttpBackupApi implements BackupApi {
  HttpBackupApi(this.api);
  final ApiClient api;

  @override
  Future<void> upload(List<int> gz, String sha256, Map<String, int> counts) =>
      api.post(
        '/backups',
        FormData.fromMap({
          'file': MultipartFile.fromBytes(gz, filename: 'cahier.json.gz'),
          'sha256': sha256,
          'counts': jsonEncode(counts),
        }),
      );

  @override
  Future<BackupMeta?> latest() async {
    try {
      final r = await api.get('/backups/latest');
      return BackupMeta(
        id: r['id'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
        sha256: r['sha256'] as String,
      );
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<int>> download(String id) => api.getBytes('/backups/$id/file');
}
