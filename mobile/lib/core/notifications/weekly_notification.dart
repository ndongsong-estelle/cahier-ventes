import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Notification du dimanche 19 h : "Votre bilan de la semaine est prêt 📒". Désactivable.
abstract class WeeklyNotification {
  Future<void> init({required void Function() onOpenBilan});
  Future<void> schedule();
  Future<void> cancel();
}

const weeklyText = 'Votre bilan de la semaine est prêt 📒';
const _id = 7;

/// Prochain dimanche 19 h (aujourd'hui si on est dimanche avant 19 h).
DateTime nextSunday19h(DateTime now) {
  var d = DateTime(now.year, now.month, now.day, 19);
  while (d.weekday != DateTime.sunday || !d.isAfter(now)) {
    d = DateTime(d.year, d.month, d.day + 1, 19);
  }
  return d;
}

class LocalWeeklyNotification implements WeeklyNotification {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  Future<void> init({required void Function() onOpenBilan}) async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Douala'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (_) => onOpenBilan(),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) onOpenBilan();
    _ready = true;
  }

  @override
  Future<void> schedule() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    final next = nextSunday19h(DateTime.now());
    await _plugin.zonedSchedule(
      id: _id,
      scheduledDate: tz.TZDateTime(
        tz.local,
        next.year,
        next.month,
        next.day,
        19,
      ),
      title: 'Cahier de ventes',
      body: weeklyText,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'bilan',
          'Bilan de la semaine',
          importance: Importance.defaultImportance,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'bilan',
    );
  }

  @override
  Future<void> cancel() => _plugin.cancel(id: _id);
}
