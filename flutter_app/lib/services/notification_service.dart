import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.showNotificationFromRemote(message);
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notifPlugin = FlutterLocalNotificationsPlugin();

  static const String channelCritical = 'mamaguard_critical';
  static const String channelTeleconsultation = 'mamaguard_teleconsultation';
  static const String channelReminder = 'mamaguard_reminder';
  static const String channelGeneral = 'mamaguard_general';

  static Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _notifPlugin.initialize(const InitializationSettings(android: androidInit, iOS: iosInit));

    await _createChannels();

    // Android 13+ requires a runtime notification permission
    try {
      await _notifPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(showNotificationFromRemote);
    FirebaseMessaging.onMessageOpenedApp.listen(showNotificationFromRemote);
  }

  static Future<void> showNotificationFromRemote(RemoteMessage message) async {
    final type = message.data['type'] ?? '';
    final title = message.notification?.title ?? (message.data['title'] ?? 'MamaGuard');
    final body = message.notification?.body ?? (message.data['body'] ?? '');

    String channel;
    if (type == 'risk_alert') {
      channel = channelCritical;
    } else if (type == 'teleconsultation') {
      channel = channelTeleconsultation;
    } else if (type == 'rappel' || type == 'appointment' || type == 'rendez_vous') {
      channel = channelReminder;
    } else {
      channel = channelGeneral;
    }

    try {
      await _showAlarm(
        id: message.messageId.hashCode,
        title: title,
        body: body,
        channel: channel,
      );
    } catch (_) {}
  }

  static Future<void> _createChannels() async {
    // Firebase fallback channel: used when a message has no channel specified.
    // Created here with high importance so even "unchanneled" messages ring.
    const fallbackChannel = AndroidNotificationChannel(
      'fcm_fallback_notification_channel',
      'MamaGuard',
      description: 'Notifications MamaGuard',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const settingsDefault = AndroidNotificationChannel(
      'default',
      'MamaGuard',
      description: 'Notifications par défaut',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const settings = AndroidNotificationChannel(
      'mamaguard_general',
      'MamaGuard',
      description: 'Notifications générales MamaGuard',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const settingsCritical = AndroidNotificationChannel(
      'mamaguard_critical',
      'Alertes sanitaires',
      description: 'Alertes sanitaires urgentes',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const settingsTeleconsultation = AndroidNotificationChannel(
      'mamaguard_teleconsultation',
      'Téléconsultations',
      description: 'Téléconsultations et invitations',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const settingsReminder = AndroidNotificationChannel(
      'mamaguard_reminder',
      'Rappels de consultation',
      description: 'Rappels de rendez-vous et de consultation',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidImpl = _notifPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // All channels use the bundled alarm sound on the alarm audio stream,
    // so MamaGuard rings loudly regardless of the notification volume.
    const alarmSound = RawResourceAndroidNotificationSound('alarm');
    const alarmUsage = AudioAttributesUsage.alarm;

    await androidImpl?.createNotificationChannel(AndroidNotificationChannel(
      fallbackChannel.id,
      fallbackChannel.name,
      description: fallbackChannel.description,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      sound: alarmSound,
      audioAttributesUsage: alarmUsage,
    ));
    await androidImpl?.createNotificationChannel(AndroidNotificationChannel(
      settingsDefault.id,
      settingsDefault.name,
      description: settingsDefault.description,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      sound: alarmSound,
      audioAttributesUsage: alarmUsage,
    ));
    await androidImpl?.createNotificationChannel(AndroidNotificationChannel(
      settings.id,
      settings.name,
      description: settings.description,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      sound: alarmSound,
      audioAttributesUsage: alarmUsage,
    ));
    await androidImpl?.createNotificationChannel(AndroidNotificationChannel(
      settingsCritical.id,
      settingsCritical.name,
      description: settingsCritical.description,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      sound: alarmSound,
      audioAttributesUsage: alarmUsage,
    ));
    await androidImpl?.createNotificationChannel(AndroidNotificationChannel(
      settingsTeleconsultation.id,
      settingsTeleconsultation.name,
      description: settingsTeleconsultation.description,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      sound: alarmSound,
      audioAttributesUsage: alarmUsage,
    ));
    await androidImpl?.createNotificationChannel(AndroidNotificationChannel(
      settingsReminder.id,
      settingsReminder.name,
      description: settingsReminder.description,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      sound: alarmSound,
      audioAttributesUsage: alarmUsage,
    ));
  }

  static Future<void> _showAlarm({
    required int id,
    required String title,
    required String body,
    required String channel,
  }) async {
    try {
      await _notifPlugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel,
            channel,
            channelDescription: 'MamaGuard',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            sound: const RawResourceAndroidNotificationSound('alarm'),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            visibility: NotificationVisibility.public,
            fullScreenIntent: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'alarm.caf',
          ),
        ),
      );
    } catch (_) {}
  }
}
