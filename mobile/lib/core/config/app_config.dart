/// Adresse du serveur. PILOT_API_URL (--dart-define) sinon l'émulateur Android (10.0.2.2).
abstract final class AppConfig {
  static const apiUrl = String.fromEnvironment(
    'PILOT_API_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );
}
