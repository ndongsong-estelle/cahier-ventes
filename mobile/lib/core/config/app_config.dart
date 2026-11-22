/// Configuration de build (--dart-define).
abstract final class AppConfig {
  /// Adresse de l'API. Vide = développement sur l'émulateur Android (10.0.2.2).
  static const _pilotApiUrl = String.fromEnvironment('PILOT_API_URL');
  static const apiUrl = _pilotApiUrl == ''
      ? 'http://10.0.2.2:8000/api'
      : _pilotApiUrl;

  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  /// Numéro WhatsApp de l'aide, remplacé par /config dès que le serveur répond.
  static const supportWhatsapp = String.fromEnvironment(
    'SUPPORT_WHATSAPP',
    defaultValue: '',
  );

  /// Racine du site (pages publiques comme /confidentialite).
  static String get siteUrl =>
      apiUrl.endsWith('/api') ? apiUrl.substring(0, apiUrl.length - 4) : apiUrl;
}
