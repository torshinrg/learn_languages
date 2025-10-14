// Defines application-level configuration derived from environment variables.

class AppConfig {
  AppConfig({required this.translator});

  final TranslatorConfig translator;
}

class TranslatorConfig {
  TranslatorConfig({required String baseUrl, String? apiKey})
    : _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
      apiKey = (apiKey ?? '').trim();

  final String _baseUrl;
  final String apiKey;

  String get baseUrl => _baseUrl;

  bool get isEnabled => _baseUrl.isNotEmpty;

  bool get hasApiKey => apiKey.isNotEmpty;

  Uri? translateEndpoint() {
    if (!isEnabled) return null;
    final base = Uri.tryParse(_baseUrl);
    if (base == null) return null;
    return base.resolve('translate');
  }
}
