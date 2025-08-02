// lib/services/audio_check_service.dart
// Platform-specific implementation loader.

export 'audio_check_service_ggml.dart'
    if (dart.library.html) 'audio_check_service_web.dart';
