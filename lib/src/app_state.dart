import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'jalali.dart';
import 'models.dart';
import 'task_logic.dart';
import 'ui_helpers.dart';

// ============================================================
// وضعیت برنامه، ذخیره‌سازی، کش تقویم و نوتیفیکیشن
// ============================================================
final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();
final AppState app = AppState();
final GlobalKey<ScaffoldMessengerState> msgKey = GlobalKey<ScaffoldMessengerState>();

class AppState extends ChangeNotifier {
  List<Task> tasks = [];
  List<Reminder> reminders = [];
  List<Tpl> tpls = [];
  bool dark = true;
  String themeId = 'classic';
  String selectedDate = today();
  Map<String, int> timers = {};
  final Set<String> ex = {};
  final ValueNotifier<int> timerTick = ValueNotifier<int>(0);

  Future<void> _q = Future.value();
  String _lastSchedSig = '';
  int _lastMin = -1;
  int _rev = 0;
  final Map<String, List<Item>> _itemsCache = {};
  String _cacheKey = '';

  void _clearCache() {
    _rev++;
    _itemsCache.clear();
    _cacheKey = '';
  }

  String _computeTasksKey() =>
      '$_rev|${today()}|${tasks.length}|${Object.hashAll(tasks.map((t) => Object.hash(t.id, t.title, t.note, t.due, t.completed, t.alarm.type, t.alarm.time, t.alarm.date, Object.hashAll(t.alarm.days), Object.hashAll(t.alarm.doms), Object.hashAll(t.log), Object.hashAll(t.skipped), t.subs.length, Object.hashAll(t.subs.map((s) => s.done)))))}';

  List<Item> cachedItemsOn(String d) {
    final ck = _computeTasksKey();
    if (ck != _cacheKey) {
      _itemsCache.clear();
      _cacheKey = ck;
    }
    return _itemsCache.putIfAbsent(d, () {
      final T = today();
      final o = <Item>[];
      for (final t in tasks) {
        if (t.due == d) {
          o.add(Item(t, 'live', d));
        } else if (isRec(t)) {
          if (t.log.contains(d)) {
            o.add(Item(t, 'mdone', d));
          } else if (d.compareTo(T) > 0 && occurs(t, d)) {
            o.add(Item(t, 'plan', d));
          }
        }
      }
      o.sort((a, b) => byTime(a.t, b.t));
      return o;
    });
  }

  String _schedSig() {
    final sb = StringBuffer();
    for (final t in tasks) {
      if (t.completed || t.alarm.type == 'none') continue;
      sb.write('${t.id}:${t.title}:${t.due}:${t.alarm.type}:${t.alarm.time}:${t.alarm.date}:${t.alarm.days.join(",")}:${t.alarm.doms.join(",")}:${t.log.length}:${t.skipped.join(",")};');
    }
    for (final r in reminders) {
      sb.write('rem:${r.id}:${r.title}:${r.note}:${r.date}:${r.time}:${r.offsets.join(",")};');
    }
    for (final e in timers.entries) {
      sb.write('tm:${e.key}:${e.value};');
    }
    return sb.toString();
  }

  Map<String, dynamic> toJson() => {
        'v': 3,
        'dark': dark,
        'theme': themeId,
        'timers': timers,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'reminders': reminders.map((r) => r.toJson()).toList(),
        'tpls': tpls.map((t) => t.toJson()).toList(),
      };

  void apply(dynamic j) {
    if (j is! Map) throw 'bad backup';
    final m = Map<String, dynamic>.from(j);
    if (m['tasks'] is! List || m['tpls'] is! List) throw 'bad backup';
    tasks = (m['tasks'] as List).map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    reminders = ((m['reminders'] ?? []) as List).map((e) => Reminder.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    tpls = (m['tpls'] as List).map((e) => Tpl.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    dark = m['dark'] != false;
    final savedTheme = m['theme'];
    themeId = savedTheme is String && const {'classic', 'glass', 'ocean', 'warm'}.contains(savedTheme) ? savedTheme : 'classic';
    timers = ((m['timers'] ?? {}) as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    _clearCache();
  }

  void seed() {
    tasks = [];
    reminders = [];
    timers = {};
    tpls = [];
    _clearCache();
  }

  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/taskmanager.json');

  Future<void> load() async {
    await _q;
    try {
      final f = await _file();
      if (await f.exists()) {
        final raw = await f.readAsString();
        try {
          apply(jsonDecode(raw));
        } catch (_) {
          final bak = File('${f.path}.corrupt');
          try {
            await f.copy(bak.path);
          } catch (_) {}
          if (tasks.isEmpty && tpls.isEmpty) seed();
        }
      } else {
        seed();
        _q = _q.catchError((_) {}).then((_) => _persist(sched: false));
      }
    } catch (_) {
      if (tasks.isEmpty && tpls.isEmpty) seed();
    }
    _clearCache();
    notifyListeners();
  }

  Future<void> _persist({bool sched = true}) async {
    try {
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(toJson()), flush: true);
      await tmp.rename(f.path);
    } catch (_) {}
    if (!sched) return;
    final sig = _schedSig();
    if (sig == _lastSchedSig) return;
    try {
      await reschedule();
      _lastSchedSig = sig;
    } catch (_) {}
  }

  void save({bool sched = true}) {
    _clearCache();
    notifyListeners();
    _q = _q.catchError((_) {}).then((_) => _persist(sched: sched));
  }

  // ----- اکشن‌ها -----
  void toggleEx(String id) {
    ex.contains(id) ? ex.remove(id) : ex.add(id);
    notifyListeners();
  }

  void setDark(bool value) {
    if (dark == value) return;
    dark = value;
    save(sched: false);
  }

  void setTheme(String value) {
    if (!const {'classic', 'glass', 'ocean', 'warm'}.contains(value) || themeId == value) return;
    themeId = value;
    save(sched: false);
  }

  void toggleChk(Task t) {
    if (t.completed) {
      t.completed = false;
      if (t.due.compareTo(today()) < 0) t.due = today();
    } else {
      completeTask(t);
      toast(isRec(t) ? 'انجام شد — نوبت بعدی ${jfmt(t.due)}' : 'تسک انجام شد ✓');
    }
    save(sched: true);
  }

  void toggleSub(Task t, Sub s) {
    s.done = !s.done;
    var statusChanged = false;
    if (t.subs.every((x) => x.done)) {
      completeTask(t);
      statusChanged = true;
      toast(isRec(t) ? 'انجام شد — نوبت بعدی ${jfmt(t.due)}' : 'تسک انجام شد ✓');
    } else if (t.completed) {
      t.completed = false;
      statusChanged = true;
      if (t.due.compareTo(today()) < 0) t.due = today();
      toast('تسک دوباره به «در حال انجام» برگشت');
    }
    save(sched: statusChanged);
  }

  void toggleOcc(Task t, String d) {
    t.log.remove(d);
    if (d.compareTo(t.due) < 0) t.due = d;
    toast('تیک این نوبت برداشته شد');
    save(sched: true);
  }

  void skipOcc(Task t, String d) {
    if (!isRec(t) || t.skipped.contains(d) || t.log.contains(d)) return;
    t.skipped.add(d);
    if (t.due == d) t.due = nextOpen(t, mx(addD(d, 1), today()));
    toast('این نوبت رد شد؛ نوبت‌های بعدی باقی می‌مانند');
    save(sched: true);
  }

  void deleteTask(String id) {
    tasks.removeWhere((t) => t.id == id);
    timers.remove(id);
    toast('حذف شد');
    save(sched: true);
  }

  void putReminder(Reminder reminder) {
    final i = reminders.indexWhere((r) => r.id == reminder.id);
    if (i < 0) {
      reminders.insert(0, reminder);
    } else {
      reminders[i] = reminder;
    }
    save(sched: true);
  }

  void completeReminder(String id) {
    reminders.removeWhere((r) => r.id == id);
    timers.remove(id);
    toast('یادآوری انجام و پاک شد ✓');
    save(sched: true);
  }

  void deleteReminder(String id) {
    reminders.removeWhere((r) => r.id == id);
    timers.remove(id);
    save(sched: true);
  }

  List<Reminder> remindersOn(String date) => reminders.where((r) => r.date == date).toList()
    ..sort((a, b) => a.time.compareTo(b.time));

  void startTimer(String id, int minutes) {
    timers[id] = DateTime.now().millisecondsSinceEpoch + minutes * 60000;
    save(sched: true);
  }

  void cancelTimer(String id) {
    timers.remove(id);
    save(sched: true);
  }

  int timerLeft(String id) {
    final e = timers[id];
    if (e == null) return 0;
    final l = e - DateTime.now().millisecondsSinceEpoch;
    return l > 0 ? l : 0;
  }

  void tick() {
    final now = DateTime.now();
    final ms = now.millisecondsSinceEpoch;
    final old = timers.entries.where((e) => e.value < ms - 120000).map((e) => e.key).toList();
    if (old.isNotEmpty) {
      for (final k in old) {
        timers.remove(k);
      }
      save(sched: true);
      return;
    }
    if (timers.isNotEmpty) {
      timerTick.value++;
    }
    if (now.minute != _lastMin) {
      _lastMin = now.minute;
      notifyListeners();
    }
  }

  // ----- اکشن‌های روی نوتیفیکیشن -----
  Future<void> onNotifAction(String? action, String? payload) async {
    if (payload == null || action == null || action.isEmpty) return;
    final p = payload.split('|');
    if (p.length < 2) return;
    final kind = p[0], id = p[1];
    final i = tasks.indexWhere((t) => t.id == id);
    final reminderExists = reminders.any((r) => r.id == id);
    if (action == 'done' && kind == 'reminder' && reminderExists) {
      reminders.removeWhere((r) => r.id == id);
      timers.remove(id);
    } else if (action == 'done' && kind == 'timer' && reminderExists) {
      reminders.removeWhere((r) => r.id == id);
      timers.remove(id);
    } else if (action == 'done' && i >= 0) {
      final t = tasks[i];
      if (!t.completed) {
        for (final s in t.subs) {
          s.done = true;
        }
        completeTask(t);
      }
      timers.remove(id);
    } else if (action == 'snooze' && (i >= 0 || reminderExists)) {
      timers[id] = DateTime.now().millisecondsSinceEpoch + 10 * 60000;
    }
    save(sched: true);
    await _q;
  }

  NotificationDetails _details() => NotificationDetails(
        android: AndroidNotificationDetails(
          'tasks',
          'یادآوری‌ها',
          channelDescription: 'یادآوری‌های تسک و اعلان‌های شخصی',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          actions: [
            AndroidNotificationAction('done', 'انجام شد', cancelNotification: true),
            AndroidNotificationAction('snooze', '۱۰ دقیقه دیگه', cancelNotification: true),
          ],
        ),
      );

  Future<void> _sched(int id, String title, String body, String payload, DateTime dt) async {
    final when = tz.TZDateTime.from(dt.toUtc(), tz.UTC);
    for (final mode in [AndroidScheduleMode.exactAllowWhileIdle, AndroidScheduleMode.inexactAllowWhileIdle]) {
      try {
        await fln.zonedSchedule(id, title, body, when, _details(), androidScheduleMode: mode, payload: payload);
        return;
      } catch (_) {}
    }
  }

  Future<void> reschedule() async {
    for (final p in await fln.pendingNotificationRequests()) {
      await fln.cancel(p.id);
    }
    final now = DateTime.now();
    int count = 0;
    for (final t in tasks) {
      if (t.completed || t.alarm.type == 'none') continue;
      final dates = <String>[];
      if (t.alarm.type == 'once') {
        dates.add(t.due);
      } else {
        for (int i = 0; i < 60 && dates.length < 20; i++) {
          final d = addD(today(), i);
          if (occurs(t, d) && !t.log.contains(d)) dates.add(d);
        }
      }
      for (final d in dates) {
        final dt = atTime(d, t.alarm.time);
        if (dt.isAfter(now)) {
          await _sched(nid('${t.id}|$d'), t.title, 'زمان انجام این کار رسیده ⏰', 'task|${t.id}', dt);
          if (++count > 400) return;
        }
      }
    }
    for (final r in reminders) {
      final due = atTime(r.date, r.time);
      for (final offset in r.offsets.toSet()) {
        final early = due.subtract(Duration(minutes: offset));
        if (early.isAfter(now)) {
          await _sched(
            nid('reminder|${r.id}|$offset'),
            r.title,
            'پیش‌یادآوری · موعد ${jfmt(r.date)} ساعت ${r.time}',
            'reminder|${r.id}',
            early,
          );
          if (++count > 400) return;
        }
      }
      if (due.isAfter(now)) {
        await _sched(nid('reminder|${r.id}|main'), r.title, r.note.isEmpty ? 'زمان یادآوری رسید ⏰' : r.note, 'reminder|${r.id}', due);
        if (++count > 400) return;
      }
    }
    for (final e in timers.entries) {
      final dt = DateTime.fromMillisecondsSinceEpoch(e.value);
      if (dt.isAfter(now)) {
        final i = tasks.indexWhere((t) => t.id == e.key);
        final ri = reminders.indexWhere((r) => r.id == e.key);
        final reminder = ri >= 0 ? reminders[ri] : null;
        await _sched(nid('timer|${e.key}'), i >= 0 ? tasks[i].title : reminder?.title ?? 'تایمر', 'وقتشه برگردی سراغ این کار ⏳', 'timer|${e.key}', dt);
      }
    }
  }
}

List<Item> itemsOn(String d) => app.cachedItemsOn(d);

Future<void> initNotif({bool withCallbacks = true}) async {
  tzdata.initializeTimeZones();
  const init = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
  if (withCallbacks) {
    await fln.initialize(
      init,
      onDidReceiveNotificationResponse: (r) => app.onNotifAction(r.actionId, r.payload),
      onDidReceiveBackgroundNotificationResponse: bgResp,
    );
  } else {
    await fln.initialize(init);
  }
}

@pragma('vm:entry-point')
Future<void> bgResp(NotificationResponse r) async {
  DartPluginRegistrant.ensureInitialized();
  await initNotif(withCallbacks: false);
  await app.load();
  await app.onNotifAction(r.actionId, r.payload);
}

Future<void> askPerms() async {
  final a = fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  try {
    await a?.requestNotificationsPermission();
    await a?.requestExactAlarmsPermission();
  } catch (_) {}
}

Future<void> exportBackup() async {
  try {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/task_backup_${today()}.json');
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(app.toJson()));
    await Share.shareXFiles([XFile(f.path)], text: 'پشتیبان وظایف من');
  } catch (_) {
    toast('ساخت فایل پشتیبان ناموفق بود');
  }
}

Future<void> importBackup(BuildContext c) async {
  final ok = await showDialog<bool>(
    context: c,
    builder: (dc) => AlertDialog(
      backgroundColor: pal.card,
      title: tx('بازگردانی اطلاعات', w: FontWeight.bold),
      content: tx('اطلاعات فعلی با محتوای فایل پشتیبان جایگزین می‌شود. ادامه می‌دهی؟', color: pal.mut),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc, false), child: tx('انصراف', color: pal.mut)),
        TextButton(onPressed: () => Navigator.pop(dc, true), child: tx('انتخاب فایل', color: pal.acc)),
      ],
    ),
  );
  if (ok != true) return;
  try {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = r?.files.single.path;
    if (path == null) return;
    app.apply(jsonDecode(await File(path).readAsString()));
    app.save(sched: true);
    toast('اطلاعات بازگردانی شد ✓');
  } catch (_) {
    toast('فایل پشتیبان معتبر نیست');
  }
}
