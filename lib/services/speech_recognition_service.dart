import 'speech_recognition_service_web.dart'
    if (dart.library.io) 'speech_recognition_service_mobile.dart' as impl;

typedef SpeechRecognitionService = impl.SpeechRecognitionService;
