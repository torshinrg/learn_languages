// lib/services/notification_service.dart
export 'notification_service_mobile.dart'
    if (dart.library.html) 'notification_service_web.dart';
