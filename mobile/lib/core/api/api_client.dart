import 'package:dio/dio.dart';

/// Erreur réseau ou serveur, avec le code stable renvoyé par l'API.
class ApiException implements Exception {
  ApiException({this.status, this.code, this.message, this.data});

  final int? status;
  final String? code;
  final String? message;
  final Map<String, dynamic>? data;

  /// Pas de réseau ou serveur injoignable.
  bool get isNetwork => status == null;

  @override
  String toString() => 'ApiException($status, $code, $message)';
}

typedef TokenReader = Future<String?> Function();

/// Client HTTP unique. Ajoute le token, retient l'heure du serveur, signale les 401.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenReader token,
    this.onServerTime,
    this.onUnauthorized,
    HttpClientAdapter? adapter,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 30),
           headers: {'Accept': 'application/json'},
         ),
       ) {
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final t = await token();
          if (t != null) options.headers['Authorization'] = 'Bearer $t';
          handler.next(options);
        },
        onResponse: (response, handler) {
          _readServerTime(response.data);
          handler.next(response);
        },
        onError: (error, handler) {
          final r = error.response;
          if (r != null) _readServerTime(r.data);
          if (r?.statusCode == 401 &&
              error.requestOptions.headers.containsKey('Authorization')) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
  void Function(DateTime serverTime)? onServerTime;
  void Function()? onUnauthorized;

  void _readServerTime(Object? data) {
    if (data is Map && data['server_time'] is String) {
      final t = DateTime.tryParse(data['server_time'] as String);
      if (t != null) onServerTime?.call(t);
    }
  }

  Future<Map<String, dynamic>> get(String path) =>
      _send(() => dio.get<Object>(path));

  Future<Map<String, dynamic>> post(String path, [Object? body]) =>
      _send(() => dio.post<Object>(path, data: body));

  Future<Map<String, dynamic>> patch(String path, [Object? body]) =>
      _send(() => dio.patch<Object>(path, data: body));

  Future<Map<String, dynamic>> delete(String path, [Object? body]) =>
      _send(() => dio.delete<Object>(path, data: body));

  Future<Map<String, dynamic>> _send(
    Future<Response<Object>> Function() call,
  ) async {
    try {
      final r = await call();
      final data = r.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } on DioException catch (e) {
      final r = e.response;
      if (r == null) throw ApiException();
      final data = r.data is Map<String, dynamic>
          ? r.data as Map<String, dynamic>
          : null;
      throw ApiException(
        status: r.statusCode,
        code: data?['code'] as String?,
        message: data?['message'] as String?,
        data: data,
      );
    }
  }
}
