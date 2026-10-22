import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show DartPluginRegistrant;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// ============================================================
// تاریخ، تقویم شمسی و اعداد فارسی
// ============================================================
const MN = ['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];
const DN = ['یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه'];
const DORD = [6, 0, 1, 2, 3, 4, 5];

String pad(int n) => n.toString().padLeft(2, '0');
String ds(DateTime d) => '${d.year}-${pad(d.month)}-${pad(d.day)}';
DateTime pd(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String addD(String s, int n) {
  final d = pd(s);
  return ds(DateTime(d.year, d.month, d.day + n));
}

String today() => ds(DateTime.now());
int wd(String s) => pd(s).weekday % 7; // یکشنبه=۰ ... شنبه=۶
String fa(Object o) => o.toString().replaceAllMapped(RegExp(r'\d'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]);
String toEn(String s) {
  const f = '۰۱۲۳۴۵۶۷۸۹';
  var r = s;
  for (int i = 0; i < 10; i++) {
    r = r.replaceAll(f[i], '$i');
  }
  return r;
}

List<int> g2j(int gy, int gm, int gd) {
  const m = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  int jy = gy <= 1600 ? 0 : 979;
  gy -= gy <= 1600 ? 621 : 1600;
  final g2 = gm > 2 ? gy + 1 : gy;
  int days = 365 * gy + ((g2 + 3) ~/ 4) - ((g2 + 99) ~/ 100) + ((g2 + 399) ~/ 400) - 80 + gd + m[gm - 1];
  jy += 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
  final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
  return [jy, jm, jd];
}

List<int> j2g(int jy, int jm, int jd) {
  int gy = jy <= 979 ? 621 : 1600;
  jy -= jy <= 979 ? 0 : 979;
  int days = 365 * jy + (jy ~/ 33) * 8 + (((jy % 33) + 3) ~/ 4) + 78 + jd + (jm < 7 ? (jm - 1) * 31 : ((jm - 7) * 30) + 186);
  gy += 400 * (days ~/ 146097);
  days %= 146097;
  if (days > 36524) {
    days--;
    gy += 100 * (days ~/ 36524);
    days %= 36524;
    if (days >= 365) days++;
  }
  gy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    gy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  int gd = days + 1;
  final sal = [0, 31, ((gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  int gm = 0;
  while (gm < 13 && gd > sal[gm]) {
    gd -= sal[gm];
    gm++;
  }
  return [gy, gm, gd];
}

int mlen(int m) => m <= 6 ? 31 : (m <= 11 ? 30 : 29);
List<int> jl(String s) {
  final p = s.split('-').map(int.parse).toList();
  return g2j(p[0], p[1], p[2]);
}

String fromJ(int y, int m, int d) {
  final g = j2g(y, m, min(d, mlen(m)));
  return '${g[0]}-${pad(g[1])}-${pad(g[2])}';
}

String jfmt(String s) {
  final j = jl(s);
  return '${j[2]} ${MN[j[1] - 1]}';
}

String uid() => DateTime.now().microsecondsSinceEpoch.toRadixString(36) + Random().nextInt(99999).toRadixString(36);

// ============================================================
// مدل داده
// ============================================================
class Sub {
  String id, t;
  bool done;
  String? tp;
  Sub(this.id, this.t, {this.done = false, this.tp});
  Map<String, dynamic> toJson() => {'id': id, 't': t, 'done': done, 'tp': tp};
  factory Sub.fromJson(Map<String, dynamic> j) => Sub(j['id'] as String, j['t'] as String, done: j['done'] == true, tp: j['tp'] as String?);
}

class Alarm {
  String type, time, date;
  List<int> days, doms;
  Alarm({this.type = 'none', this.time = '09:00', String? date, List<int>? days, List<int>? doms})
      : date = date ?? today(),
        days = days ?? [],
        doms = doms ?? [];
  Map<String, dynamic> toJson() => {'type': type, 'time': time, 'date': date, 'days': days, 'doms': doms};
  factory Alarm.fromJson(Map<String, dynamic> j) => Alarm(
        type: (j['type'] ?? 'none') as String,
        time: (j['time'] ?? '09:00') as String,
        date: j['date'] as String?,
        days: ((j['days'] ?? []) as List).map((e) => (e as num).toInt()).toList(),
        doms: ((j['doms'] ?? []) as List).map((e) => (e as num).toInt()).toList(),
      );
}

class Task {
  String id, title, note, due, created;
  List<Sub> subs;
  Alarm alarm;
  bool completed;
  List<String> log;
  String? tpl;
  Task({required this.id, required this.title, this.note = '', List<Sub>? subs, Alarm? alarm, String? due, this.completed = false, String? created, List<String>? log, this.tpl})
      : subs = subs ?? [],
        alarm = alarm ?? Alarm(),
        due = due ?? today(),
        created = created ?? today(),
        log = log ?? [];
  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'note': note, 'due': due, 'created': created, 'completed': completed, 'tpl': tpl,
        'subs': subs.map((s) => s.toJson()).toList(), 'alarm': alarm.toJson(), 'log': log,
      };
  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        note: (j['note'] ?? '') as String,
        due: j['due'] as String?,
        created: j['created'] as String?,
        completed: j['completed'] == true,
        tpl: j['tpl'] as String?,
        subs: ((j['subs'] ?? []) as List).map((e) => Sub.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        alarm: Alarm.fromJson(Map<String, dynamic>.from((j['alarm'] ?? {}) as Map)),
        log: ((j['log'] ?? []) as List).map((e) => e.toString()).toList(),
      );
  Task clone() => Task.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(toJson())) as Map));
}

class Tpl {
  String id, name;
  List<String> steps;
  Tpl(this.id, this.name, this.steps);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'steps': steps};
  factory Tpl.fromJson(Map<String, dynamic> j) => Tpl(j['id'] as String, j['name'] as String, ((j['steps'] ?? []) as List).map((e) => e.toString()).toList());
}

class Item {
  final Task t;
  final String k, d; // k: live | mdone | plan
  Item(this.t, this.k, this.d);
}

// ============================================================
// منطق تسک‌ها و تکرار
// ============================================================
List<int> domsOf(Alarm a) => ([...a.doms]..sort());
String tmOf(Task t) => t.alarm.type != 'none' ? t.alarm.time : '';
String nowT() {
  final d = DateTime.now();
  return '${pad(d.hour)}:${pad(d.minute)}';
}

bool isRec(Task t) => t.alarm.type == 'daily' || t.alarm.type == 'weekly' || t.alarm.type == 'monthly';
bool late(Task t) => !t.completed && t.due == today() && tmOf(t).isNotEmpty && tmOf(t).compareTo(nowT()) < 0;
String st(Task t) {
  if (t.completed) return 'done';
  final c = t.subs.where((s) => s.done).length;
  return (c > 0 && c < t.subs.length) ? 'prog' : 'new';
}

int byTime(Task a, Task b) => (tmOf(a).isEmpty ? '99:99' : tmOf(a)).compareTo(tmOf(b).isEmpty ? '99:99' : tmOf(b));
String mx(String a, String b) => a.compareTo(b) > 0 ? a : b;

String nextOcc(Alarm a, String start) {
  if (a.type == 'daily') return start;
  if (a.type == 'weekly') {
    for (int i = 0; i < 8; i++) {
      final d = addD(start, i);
      if (a.days.contains(wd(d))) return d;
    }
    return start;
  }
  final dl = domsOf(a);
  final j = jl(start);
  int y = j[0], m = j[1];
  for (int k = 0; k < 3; k++) {
    final c = dl.map((d) => fromJ(y, m, d)).where((x) => x.compareTo(start) >= 0).toList()..sort();
    if (c.isNotEmpty) return c.first;
    m++;
    if (m > 12) {
      m = 1;
      y++;
    }
  }
  return start;
}

String nextOpen(Task t, String start) {
  String d = nextOcc(t.alarm, start);
  int i = 0;
  while (t.log.contains(d) && i++ < 400) {
    d = nextOcc(t.alarm, addD(d, 1));
  }
  return d;
}

bool occurs(Task t, String d) {
  final a = t.alarm;
  if (d.compareTo(t.created) < 0) return false;
  if (a.type == 'daily') return true;
  if (a.type == 'weekly') return a.days.contains(wd(d));
  if (a.type == 'monthly') {
    final j = jl(d);
    return domsOf(a).any((x) => min(x, mlen(j[1])) == j[2]);
  }
  return false;
}

void completeTask(Task t) {
  if (isRec(t)) {
    t.log.add(t.due);
    t.due = nextOpen(t, mx(addD(t.due, 1), today()));
    for (final s in t.subs) {
      s.done = false;
    }
  } else {
    t.completed = true;
  }
}

String alarmTxt(Alarm a) {
  if (a.type == 'once') return '🔔 ${jfmt(a.date)} ساعت ${a.time}';
  if (a.type == 'daily') return '🔁 هر روز ${a.time}';
  if (a.type == 'weekly') return '🔁 ${DORD.where((d) => a.days.contains(d)).map((d) => DN[d]).join('، ')} ${a.time}';
  if (a.type == 'monthly') return '🔁 روزهای ${domsOf(a).join('، ')} هر ماه ${a.time}';
  return '';
}

DateTime atTime(String d, String time) {
  final p = time.split(':');
  final x = pd(d);
  return DateTime(x.year, x.month, x.day, int.parse(p[0]), int.parse(p[1]));
}

int nid(String s) {
  int h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0x3fffffff;
  }
  return h;
}

// ============================================================
// وضعیت برنامه، ذخیره‌سازی و نوتیفیکیشن
// ============================================================
final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();
final AppState app = AppState();
final GlobalKey<ScaffoldMessengerState> msgKey = GlobalKey<ScaffoldMessengerState>();

class AppState extends ChangeNotifier {
  List<Task> tasks = [];
  List<Tpl> tpls = [];
  bool dark = true;
  Map<String, int> timers = {};
  final Set<String> ex = {};
  Future<void> _q = Future.value();

  Map<String, dynamic> toJson() => {
        'v': 1, 'dark': dark, 'timers': timers,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'tpls': tpls.map((t) => t.toJson()).toList(),
      };

  void apply(dynamic j) {
    final m = Map<String, dynamic>.from(j as Map);
    if (m['tasks'] is! List || m['tpls'] is! List) throw 'bad backup';
    tasks = (m['tasks'] as List).map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    tpls = (m['tpls'] as List).map((e) => Tpl.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    dark = m['dark'] != false;
    timers = ((m['timers'] ?? {}) as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  }

  void seed() {
    tasks = [];
    timers = {};
    tpls = [Tpl('tp1', 'ویدیو کلاس', ['آماده شدن فایل', 'کاهش حجم ویدیو', 'آپلود فایل', 'ساخت و ارسال لینک'])];
  }

  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/taskmanager.json');

  Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        apply(jsonDecode(await f.readAsString()));
      } else {
        seed();
        _q = _q.then((_) => _persist());
      }
    } catch (_) {
      if (tasks.isEmpty && tpls.isEmpty) seed();
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(toJson()), flush: true);
      await tmp.rename(f.path);
    } catch (_) {}
    try {
      await reschedule();
    } catch (_) {}
  }

  void save() {
    notifyListeners();
    _q = _q.then((_) => _persist());
  }

  // ----- اکشن‌ها -----
  void toggleEx(String id) {
    ex.contains(id) ? ex.remove(id) : ex.add(id);
    notifyListeners();
  }

  void toggleChk(Task t) {
    if (t.completed) {
      t.completed = false;
      if (t.due.compareTo(today()) < 0) t.due = today();
    } else {
      completeTask(t);
      toast(isRec(t) ? 'انجام شد — نوبت بعدی ${jfmt(t.due)}' : 'تسک انجام شد ✓');
    }
    save();
  }

  void toggleSub(Task t, Sub s) {
    s.done = !s.done;
    if (t.subs.every((x) => x.done)) {
      completeTask(t);
      toast(isRec(t) ? 'انجام شد — نوبت بعدی ${jfmt(t.due)}' : 'تسک انجام شد ✓');
    } else if (t.completed) {
      t.completed = false;
      if (t.due.compareTo(today()) < 0) t.due = today();
      toast('تسک دوباره به «در حال انجام» برگشت');
    }
    save();
  }

  void toggleOcc(Task t, String d) {
    t.log.remove(d);
    if (d.compareTo(t.due) < 0) t.due = d;
    toast('تیک این نوبت برداشته شد');
    save();
  }

  void deleteTask(String id) {
    tasks.removeWhere((t) => t.id == id);
    timers.remove(id);
    toast('حذف شد');
    save();
  }

  void startTimer(String id, int minutes) {
    timers[id] = DateTime.now().millisecondsSinceEpoch + minutes * 60000;
    save();
  }

  void cancelTimer(String id) {
    timers.remove(id);
    save();
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
      save();
      return;
    }
    if (timers.isNotEmpty || now.second == 0) notifyListeners();
  }

  // ----- اکشن‌های روی نوتیفیکیشن -----
  Future<void> onNotifAction(String? action, String? payload) async {
    if (payload == null || action == null || action.isEmpty) return;
    final p = payload.split('|');
    if (p.length < 2) return;
    final id = p[1];
    final i = tasks.indexWhere((t) => t.id == id);
    if (action == 'done' && i >= 0) {
      final t = tasks[i];
      if (!t.completed) {
        for (final s in t.subs) {
          s.done = true;
        }
        completeTask(t);
      }
      timers.remove(id);
    } else if (action == 'snooze') {
      timers[id] = DateTime.now().millisecondsSinceEpoch + 10 * 60000;
    }
    save();
    await _q;
  }

  NotificationDetails _details() => NotificationDetails(
        android: AndroidNotificationDetails(
          'tasks', 'یادآور تسک‌ها',
          channelDescription: 'یادآوری تسک‌ها و تایمرها',
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
    final when = tz.TZDateTime.from(dt, tz.UTC);
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
    for (final e in timers.entries) {
      final dt = DateTime.fromMillisecondsSinceEpoch(e.value);
      if (dt.isAfter(now)) {
        final i = tasks.indexWhere((t) => t.id == e.key);
        await _sched(nid('timer|${e.key}'), i >= 0 ? tasks[i].title : 'تایمر', 'وقتشه برگردی سراغ این کار ⏳', 'timer|${e.key}', dt);
      }
    }
  }
}

Future<void> initNotif({bool withCallbacks = true}) async {
  tzdata.initializeTimeZones();
  const init = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
  if (withCallbacks) {
    await fln.initialize(init, onDidReceiveNotificationResponse: (r) => app.onNotifAction(r.actionId, r.payload), onDidReceiveBackgroundNotificationResponse: bgResp);
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

// ============================================================
// ظاهر: رنگ‌ها و ابزارهای کوچک
// ============================================================
class Pal {
  final Color bg, card, card2, tx, mut, acc, amb, red, grn, bd;
  const Pal(this.bg, this.card, this.card2, this.tx, this.mut, this.acc, this.amb, this.red, this.grn, this.bd);
}

const darkPal = Pal(Color(0xFF12161F), Color(0xFF1A2030), Color(0xFF222A3D), Color(0xFFEEF1F8), Color(0xFF8D97AE), Color(0xFF8B9CFF), Color(0xFFFFB547), Color(0xFFFF6B6B), Color(0xFF4CD29A), Color(0xFF2C3550));
const lightPal = Pal(Color(0xFFF3F5FA), Color(0xFFFFFFFF), Color(0xFFEAEEF7), Color(0xFF1B2233), Color(0xFF67718A), Color(0xFF4F5FE0), Color(0xFFD98300), Color(0xFFD93A3A), Color(0xFF17996A), Color(0xFFD9DEEC));
Pal get pal => app.dark ? darkPal : lightPal;

Widget tx(String s, {double size = 15, Color? color, FontWeight? w, TextAlign? align, int? maxLines, TextDecoration? deco, TextDirection? dir}) => Text(
      fa(s),
      textAlign: align,
      maxLines: maxLines,
      textDirection: dir,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      style: TextStyle(fontSize: size, color: color ?? pal.tx, fontWeight: w, decoration: deco, height: 1.5),
    );

Widget tap(VoidCallback f, Widget c) => GestureDetector(behavior: HitTestBehavior.opaque, onTap: f, child: c);

Widget ib(Widget child, VoidCallback f, {double s = 36}) => tap(f, Container(width: s, height: s, decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: child));

Widget glyph(String g) => Text(g, style: TextStyle(fontSize: 22, color: pal.tx, height: 1.1));

Widget chk(bool on, VoidCallback f, {double s = 26}) => tap(
    f,
    Container(
      width: s, height: s,
      decoration: BoxDecoration(color: on ? pal.grn : null, border: Border.all(color: on ? pal.grn : pal.mut, width: 2), borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: on ? Icon(Icons.check, size: s - 10, color: Colors.white) : null,
    ));

Widget btn(String l, VoidCallback f, {Color? bg, Color? fg, bool wide = false, EdgeInsets p = const EdgeInsets.symmetric(horizontal: 14, vertical: 8)}) => tap(
    f,
    Container(
      width: wide ? double.infinity : null,
      padding: wide ? const EdgeInsets.symmetric(vertical: 13) : p,
      decoration: BoxDecoration(color: bg ?? pal.card2, borderRadius: BorderRadius.circular(wide ? 14 : 10)),
      alignment: wide ? Alignment.center : null,
      child: tx(l, size: