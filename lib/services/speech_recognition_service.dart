// lib/services/speech_recognition_service.dart
// Exports the appropriate implementation based on the platform.

export 'speech_recognition_service_ggml.dart'
    if (dart.library.html) 'speech_recognition_service_web.dart';
