import '../api/api_client.dart';

class AuthResult {
  const AuthResult({
    required this.token,
    required this.user,
    this.mustChangePin = false,
  });

  final String token;
  final AccountUser user;
  final bool mustChangePin;
}

class AccountUser {
  const AccountUser({
    required this.id,
    required this.phone,
    required this.shopName,
  });

  factory AccountUser.fromJson(Map<String, dynamic> j) => AccountUser(
    id: '${j['id']}',
    phone: j['phone'] as String,
    shopName: j['shop_name'] as String,
  );

  final String id;
  final String phone;
  final String shopName;
}

class PhoneCheck {
  const PhoneCheck({required this.exists, required this.otpRequired});
  final bool exists;
  final bool otpRequired;
}

/// Appels /auth et /me (docs/03).
class AuthApi {
  AuthApi(this.api);
  final ApiClient api;

  Future<PhoneCheck> check(String phone) async {
    final r = await api.post('/auth/check', {'phone': phone});
    return PhoneCheck(
      exists: r['exists'] == true,
      otpRequired: r['otp_required'] == true,
    );
  }

  Future<void> sendOtp(String phone) =>
      api.post('/auth/otp/send', {'phone': phone});

  Future<String> verifyOtp(String phone, String code) async {
    final r = await api.post('/auth/otp/verify', {
      'phone': phone,
      'code': code,
    });
    return r['otp_ticket'] as String;
  }

  Future<AuthResult> register({
    required String phone,
    required String shopName,
    required String pin,
    required Map<String, dynamic> device,
    String? otpTicket,
  }) async => _result(
    await api.post('/auth/register', {
      'phone': phone,
      'shop_name': shopName,
      'pin': pin,
      'device': device,
      'otp_ticket': ?otpTicket,
    }),
  );

  Future<AuthResult> login({
    required String phone,
    required String pin,
    required Map<String, dynamic> device,
  }) async => _result(
    await api.post('/auth/login', {
      'phone': phone,
      'pin': pin,
      'device': device,
    }),
  );

  Future<AuthResult> resetPin({
    required String phone,
    required String otpTicket,
    required String newPin,
    required Map<String, dynamic> device,
  }) async => _result(
    await api.post('/auth/pin/reset', {
      'phone': phone,
      'otp_ticket': otpTicket,
      'new_pin': newPin,
      'device': device,
    }),
  );

  Future<void> changePin(String current, String next) =>
      api.post('/auth/pin', {'current_pin': current, 'new_pin': next});

  Future<AccountUser> updateShopName(String name) async {
    final r = await api.patch('/me', {'shop_name': name});
    return AccountUser.fromJson(r['user'] as Map<String, dynamic>);
  }

  Future<void> logout() => api.post('/auth/logout');

  Future<void> deleteAccount(String pin) => api.delete('/me', {'pin': pin});

  AuthResult _result(Map<String, dynamic> r) => AuthResult(
    token: r['token'] as String,
    user: AccountUser.fromJson(r['user'] as Map<String, dynamic>),
    mustChangePin: r['must_change_pin'] == true,
  );
}
