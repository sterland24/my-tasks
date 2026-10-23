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
      child: tx(l, size: wide ? 15 : 13, color: fg, w: wide ? FontWeight.bold : null),
    ));

Widget chip(String l, bool on, VoidCallback f) => tap(f, Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7), decoration: BoxDecoration(color: on ? pal.acc : pal.card2, borderRadius: BorderRadius.circular(20)), child: tx(l, size: 13, color: on ? Colors.white : pal.mut)));

Widget cardBox({required Widget child, Color? stripe, Color? bg, double op = 1}) => Opacity(
    opacity: op,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: bg ?? pal.card, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 4, color: stripe ?? pal.bd),
          Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 12), child: child)),
        ]),
      ),
    ));

Widget secH(String ti, Color col, int n) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: col, shape: BoxShape.circle)), const SizedBox(width: 8), tx('$ti ($n)', size: 14, w: FontWeight.bold)]));

Widget emptyBox(String m) => Padding(padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 10), child: Center(child: tx(m, color: pal.mut, align: TextAlign.center)));

Widget lbl(String s) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: tx(s, size: 13, color: pal.mut));

InputDecoration deco(String hint) {
  OutlineInputBorder b(Color c) => OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c));
  return InputDecoration(hintText: fa(hint), hintStyle: TextStyle(color: pal.mut), filled: true, fillColor: pal.card2, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), border: b(pal.bd), enabledBorder: b(pal.bd), focusedBorder: b(pal.acc));
}

Widget field(TextEditingController c, String hint, {int lines = 1, ValueChanged<String>? onSub}) => TextField(controller: c, minLines: lines, maxLines: lines == 1 ? 1 : 5, onSubmitted: onSub, style: TextStyle(color: pal.tx, fontFamily: 'Vazirmatn'), decoration: deco(hint));

void toast(String m) {
  final s = msgKey.currentState;
  if (s == null) return;
  s.hideCurrentSnackBar();
  s.showSnackBar(SnackBar(content: Text(fa(m), style: TextStyle(color: pal.bg, fontFamily: 'Vazirmatn')), backgroundColor: pal.tx, behavior: SnackBarBehavior.floating, duration: const Duration(milliseconds: 2200)));
}

Future<bool> confirm(BuildContext c, String title, String sub) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (dc) => AlertDialog(
      backgroundColor: pal.card,
      title: tx(title, w: FontWeight.bold),
      content: tx('«$sub»\nاین کار قابل بازگشت نیست.', color: pal.mut),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc, false), child: tx('انصراف', color: pal.mut)),
        TextButton(onPressed: () => Navigator.pop(dc, true), child: tx('بله، حذف شود', color: pal.red)),
      ],
    ),
  );
  return r == true;
}

Future<T?> sheet<T>(BuildContext c, WidgetBuilder b) => showModalBottomSheet<T>(
      context: c,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: pal.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: b,
    );

Widget sheetBody(BuildContext c, List<Widget> children) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
    child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)));

Widget sheetHead(BuildContext c, String t) => Row(children: [Expanded(child: tx(t, size: 17, w: FontWeight.bold)), ib(Icon(Icons.close, size: 18, color: pal.tx), () => Navigator.pop(c))]);

String fmtCd(int ms) {
  final s = (ms / 1000).ceil();
  return '${pad(s ~/ 60)}:${pad(s % 60)}';
}

// ============================================================
// آیتم‌های هر روز در تقویم
// ============================================================
List<Item> itemsOn(String d) {
  final T = today();
  final o = <Item>[];
  for (final t in app.tasks) {
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
}

// ============================================================
// کارت تسک
// ============================================================
Widget taskCard(BuildContext c, Task t, {String cls = ''}) {
  final n = t.subs.length, cnt = t.subs.where((s) => s.done).length, s = st(t);
  final ex = app.ex.contains(t.id), od = !t.completed && t.due.compareTo(today()) < 0, lt = late(t);
  final al = t.alarm.type == 'once' ? '🔔 ساعت ${t.alarm.time}' : alarmTxt(t.alarm), due = t.due == today() ? 'امروز' : jfmt(t.due);
  final left = app.timerLeft(t.id);
  final stripe = (cls == 'over' || lt) ? pal.red : cls == 'prog' ? pal.amb : cls == 'done' ? pal.grn : pal.bd;
  return cardBox(
    stripe: stripe,
    bg: lt ? Color.alphaBlend(pal.red.withOpacity(.12), pal.card) : null,
    op: s == 'done' ? .6 : 1,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (n == 0) ...[chk(s == 'done', () => app.toggleChk(t)), const SizedBox(width: 10)],
        Expanded(
          child: tap(
            () => app.toggleEx(t.id),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              tx(t.title, w: FontWeight.bold),
              const SizedBox(height: 2),
              Wrap(spacing: 10, children: [
                tx(od ? 'عقب‌افتاده از $due' : jfmt(t.due), size: 12, color: od ? pal.red : pal.mut),
                if (al.isNotEmpty) tx(al, size: 12, color: lt ? pal.red : pal.mut),
              ]),
            ]),
          ),
        ),
        if (s != 'done') ib(const Text('⏳', style: TextStyle(fontSize: 17)), () => openTimerSheet(c, t)),
      ]),
      if (n > 0) ...[
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: cnt / n, minHeight: 6, backgroundColor: pal.card2, valueColor: AlwaysStoppedAnimation(pal.amb))),
        const SizedBox(height: 5),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          tx('$cnt از $n مرحله', size: 12, color: pal.mut),
          tx(s == 'prog' ? 'در حال انجام' : s == 'done' ? 'تکمیل' : 'شروع نشده', size: 12, color: pal.mut),
        ]),
      ],
      if (left > 0)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: tap(
            () => app.cancelTimer(t.id),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(20)), child: tx('⏳ ${fmtCd(left)} · لغو', size: 12, color: pal.acc)),
          ),
        ),
      if (ex)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.bd))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (t.note.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Expanded(child: tx(t.note, size: 13, dir: RegExp(r'[\u0600-\u06FF]').hasMatch(t.note) ? TextDirection.rtl : TextDirection.ltr)),
                  ib(Icon(Icons.copy, size: 16, color: pal.tx), () {
                    Clipboard.setData(ClipboardData(text: t.note));
                    toast('کپی شد');
                  }, s: 32),
                ]),
              ),
            for (final x in t.subs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  chk(x.done, () => app.toggleSub(t, x), s: 22),
                  const SizedBox(width: 10),
                  Expanded(child: tx(x.t, color: x.done ? pal.mut : null, deco: x.done ? TextDecoration.lineThrough : null)),
                ]),
              ),
            const SizedBox(height: 8),
            Row(children: [
              btn('✎ ویرایش', () => openTaskForm(c, edit: t)),
              const SizedBox(width: 8),
              btn('حذف', () async {
                if (await confirm(c, 'حذف این تسک؟', t.title)) app.deleteTask(t.id);
              }, fg: pal.red),
            ]),
          ]),
        ),
    ]),
  );
}

Widget mini(Item x) {
  final t = x.t, pl = x.k == 'plan', ok = !pl && x.d.compareTo(today()) >= 0;
  final al = alarmTxt(t.alarm);
  return cardBox(
    op: pl ? 1 : .6,
    child: Row(children: [
      ok ? chk(true, () => app.toggleOcc(t, x.d)) : Container(width: 10, height: 10, margin: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: pl ? pal.mut : pal.grn, shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          tx(t.title, w: FontWeight.bold),
          Wrap(spacing: 10, children: [tx(jfmt(x.d), size: 12, color: pal.mut), if (al.isNotEmpty) tx(al, size: 12, color: pal.mut), tx(pl ? 'برنامه‌ریزی‌شده' : 'انجام شد ✓', size: 12, color: pal.mut)]),
        ]),
      ),
    ]),
  );
}

// ============================================================
// فرم تسک
// ============================================================
void openTaskForm(BuildContext ctx, {Task? edit}) {
  final e = edit;
  final t = e != null ? e.clone() : Task(id: uid(), title: '');
  if (t.alarm.type == 'none') t.alarm.date = t.due;
  final tc = TextEditingController(text: t.title), nc = TextEditingController(text: t.note), sc = TextEditingController();
  sheet<void>(
    ctx,
    (bc) => StatefulBuilder(builder: (bc, set) {
      final a = t.alarm;

      Future<void> pickTime() async {
        final p = a.time.split(':');
        final r = await showTimePicker(context: bc, initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])));
        if (r != null) set(() => a.time = '${pad(r.hour)}:${pad(r.minute)}');
      }

      void addSub() {
        final s = sc.text.trim();
        if (s.isEmpty) return;
        set(() {
          t.subs.add(Sub(uid(), s));
          sc.clear();
        });
      }

      Future<void> pickTpl() async {
        final id = await sheet<String>(
          bc,
          (pc) => sheetBody(pc, [
            sheetHead(pc, 'انتخاب قالب'),
            const SizedBox(height: 4),
            tx('هر تسک فقط یک قالب دارد. با انتخاب قالب دیگر، مراحل قالب قبلی جایگزین می‌شود (مراحلی که خودت اضافه کرده‌ای می‌ماند).', size: 12, color: pal.mut),
            const SizedBox(height: 12),
            if (app.tpls.isEmpty) emptyBox('هنوز قالبی نساخته‌ای.\nاز تب «قالب‌ها» یکی بساز.'),
            for (final p in app.tpls)
              tap(
                () => Navigator.pop(pc, p.id),
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.tpl == p.id ? pal.acc : Colors.transparent, width: 2)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        tx(p.name, w: FontWeight.bold),
                        tx('${p.steps.length} مرحله', size: 12, color: pal.mut),
                        for (int i = 0; i < p.steps.length; i++) tx('${i + 1}. ${p.steps[i]}', size: 12, color: pal.mut),
                      ]),
                    ),
                    Icon(t.tpl == p.id ? Icons.check_circle : Icons.add_circle_outline, color: pal.acc),
                  ]),
                ),
              ),
          ]),
        );
        if (id == null) return;
        final p = app.tpls.firstWhere((x) => x.id == id);
        set(() {
          t.subs.removeWhere((s) => s.tp != null);
          for (final x in p.steps) {
            t.subs.add(Sub(uid(), x, tp: p.id));
          }
          t.tpl = p.id;
        });
      }

      void save() {
        final title = tc.text.trim();
        if (title.isEmpty) return toast('عنوان تسک را وارد کن');
        if (a.type == 'weekly' && a.days.isEmpty) return toast('حداقل یک روز هفته انتخاب کن');
        if (a.type == 'monthly' && a.doms.isEmpty) return toast('حداقل یک روز ماه انتخاب کن');
        t.title = title;
        t.note = nc.text.trim();
        t.completed = false;
        t.due = isRec(t) ? nextOpen(t, today()) : a.date;
        if (e != null) {
          final i = app.tasks.indexWhere((x) => x.id == e.id);
          if (i >= 0) app.tasks[i] = t;
        } else {
          app.tasks.insert(0, t);
        }
        app.save();
        Navigator.pop(bc);
      }

      Widget timeBox() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            lbl('ساعت'),
            tap(pickTime, Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(12)), child: tx(a.time, size: 16, w: FontWeight.bold, color: pal.acc))),
          ]);

      Widget dd<V>(V v, List<V> items, void Function(V) f, String Function(V) lab) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<V>(
                  value: v, isExpanded: true, dropdownColor: pal.card2,
                  items: [for (final i in items) DropdownMenuItem<V>(value: i, child: tx(lab(i), size: 14))],
                  onChanged: (x) {
                    if (x != null) f(x);
                  },
                ),
              ),
            ),
          );

      Widget dateRow() {
        final jd = jl(a.date), jn = jl(today());
        final ys = <int>{jd[0], jn[0], jn[0] + 1, jn[0] + 2}.toList()..sort();
        void setD(int y, int m, int d) => set(() => a.date = fromJ(y, m, d));
        return Row(children: [
          dd<int>(jd[2], List.generate(31, (i) => i + 1), (v) => setD(jd[0], jd[1], v), (v) => '$v'),
          dd<int>(jd[1], List.generate(12, (i) => i + 1), (v) => setD(jd[0], v, jd[2]), (v) => MN[v - 1]),
          dd<int>(jd[0], ys, (v) => setD(v, jd[1], jd[2]), (v) => '$v'),
        ]);
      }

      Widget alarmUi() {
        if (a.type == 'none') return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [lbl('تاریخ (شمسی)'), dateRow()]);
        if (a.type == 'once') return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [lbl('تاریخ (شمسی)'), dateRow(), timeBox()]);
        if (a.type == 'daily') return timeBox();
        if (a.type == 'weekly') {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            lbl('روزهای هفته'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final d in DORD) chip(DN[d], a.days.contains(d), () => set(() => a.days.contains(d) ? a.days.remove(d) : a.days.add(d))),
            ]),
            timeBox(),
          ]);
        }
        if (a.type == 'monthly') {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            lbl('هر ماه شمسی در کدام روزها تکرار شود؟ (می‌توانی چند روز انتخاب کنی)'),
            GridView.count(
              crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 6, crossAxisSpacing: 6,
              children: [
                for (int d = 1; d <= 31; d++)
                  tap(
                    () => set(() => a.doms.contains(d) ? a.doms.remove(d) : a.doms.add(d)),
                    Container(alignment: Alignment.center, decoration: BoxDecoration(color: a.doms.contains(d) ? pal.acc : pal.card2, borderRadius: BorderRadius.circular(10)), child: tx('$d', size: 13, color: a.doms.contains(d) ? Colors.white : pal.mut)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            tx('اگر ماهی آن روز را نداشته باشد (مثلاً ۳۱ مهر)، آخرین روز همان ماه در نظر گرفته می‌شود.', size: 12, color: pal.mut),
            timeBox(),
          ]);
        }
        return const SizedBox.shrink();
      }

      final recOk = (a.type == 'daily') || (a.type == 'weekly' && a.days.isNotEmpty) || (a.type == 'monthly' && a.doms.isNotEmpty);
      String? pv;
      if (recOk) {
        final n = nextOpen(t, today());
        pv = '📅 اولین نوبت: ${DN[wd(n)]} ${jfmt(n)}';
      }

      return sheetBody(bc, [
        sheetHead(bc, e != null ? 'ویرایش تسک' : 'تسک جدید'),
        lbl('عنوان تسک *'),
        field(tc, 'مثلاً: ویدیو کلاس جلسه ۶'),
        lbl('یادداشت یا لینک'),
        field(nc, 'اختیاری', lines: 2),
        lbl('مراحل (چک‌لیست)'),
        ReorderableListView(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), buildDefaultDragHandles: false,
          onReorder: (o, n) => set(() {
            if (n > o) n--;
            final x = t.subs.removeAt(o);
            t.subs.insert(n, x);
          }),
          children: [
            for (int i = 0; i < t.subs.length; i++)
              Container(
                key: ValueKey(t.subs[i].id),
                color: pal.card,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  ReorderableDragStartListener(index: i, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.drag_handle, color: pal.mut))),
                  Expanded(child: tx(t.subs[i].t)),
                  tap(() => set(() => t.subs.removeAt(i)), Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close, size: 18, color: pal.red))),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: field(sc, 'مرحله جدید…', onSub: (_) => addSub())),
          const SizedBox(width: 8),
          ib(const Icon(Icons.add, color: Colors.white), addSub, s: 46),
        ]),
        const SizedBox(height: 10),
        if (t.tpl != null && app.tpls.any((p) => p.id == t.tpl))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Expanded(child: tx('▤ قالب: ${app.tpls.firstWhere((p) => p.id == t.tpl).name}', size: 13)),
              btn('حذف قالب', () => set(() {
                    t.subs.removeWhere((s) => s.tp != null);
                    t.tpl = null;
                  }), fg: pal.red),
            ]),
          ),
        tap(pickTpl, Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 11), decoration: BoxDecoration(border: Border.all(color: pal.acc), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: tx(t.tpl != null ? '▤ تغییر قالب' : '▤ انتخاب از قالب آماده', color: pal.acc))),
        lbl('یادآوری و تکرار'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final x in const [['none', 'بدون آلارم'], ['once', 'یک‌بار'], ['daily', 'روزانه'], ['weekly', 'هفتگی'], ['monthly', 'ماهانه']]) chip(x[1], a.type == x[0], () => set(() => a.type = x[0])),
        ]),
        alarmUi(),
        if (pv != null) Container(margin: const EdgeInsets.only(top: 14), padding: const EdgeInsets.all(10), width: double.infinity, decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(12)), child: tx(pv, size: 13, color: pal.acc)),
        const SizedBox(height: 18),
        btn('ذخیره تسک', save, bg: pal.acc, fg: Colors.white, wide: true),
      ]);
    }),
  );
}

// ============================================================
// تایمر سریع
// ============================================================
void openTimerSheet(BuildContext ctx, Task t) {
  final cc = TextEditingController(text: '10');
  bool custom = false;
  sheet<void>(
    ctx,
    (bc) => StatefulBuilder(builder: (bc, set) {
      void go(int m) {
        app.startTimer(t.id, m);
        Navigator.pop(bc);
        toast('تایمر $m دقیقه‌ای فعال شد');
      }

      Widget o(String l, VoidCallback f) => Expanded(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: tap(f, Container(padding: const EdgeInsets.symmetric(vertical: 16), alignment: Alignment.center, decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(14)), child: tx(l, w: FontWeight.bold))),
            ),
          );

      return sheetBody(bc, [
        sheetHead(bc, '⏳ چند دقیقه دیگه یادم بنداز'),
        tx(t.title, size: 13, color: pal.mut),
        const SizedBox(height: 12),
        Row(children: [o('۱۵ دقیقه دیگه', () => go(15)), o('۳۰ دقیقه دیگه', () => go(30))]),
        Row(children: [o('۱ ساعت دیگه', () => go(60)), o('زمان دلخواه', () => set(() => custom = true))]),
        if (custom) ...[
          lbl('زمان دلخواه (دقیقه، عدد صحیح از ۱ به بالا)'),
          Row(children: [
            Expanded(
              child: TextField(
                controller: cc, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹]'))],
                style: TextStyle(color: pal.tx, fontFamily: 'Vazirmatn'), decoration: deco('دقیقه'),
              ),
            ),
            const SizedBox(width: 8),
            ib(const Icon(Icons.check, color: Colors.white), () {
              final v = int.tryParse(toEn(cc.text));
              if (v == null || v < 1) return toast('یک عدد صحیح، از ۱ دقیقه به بالا وارد کن');
              go(v);
            }, s: 46),
          ]),
        ],
      ]);
    }),
  );
}

// ============================================================
// فرم قالب
// ============================================================
void openTplForm(BuildContext ctx, {Tpl? edit}) {
  final e = edit;
  final nc = TextEditingController(text: e?.name ?? '');
  final cs = <TextEditingController>[for (final s in (e?.steps ?? <String>[''])) TextEditingController(text: s)];
  sheet<void>(
    ctx,
    (bc) => StatefulBuilder(builder: (bc, set) {
      void save() {
        final nm = nc.text.trim();
        final steps = cs.map((c) => c.text.trim()).where((x) => x.isNotEmpty).toList();
        if (nm.isEmpty || steps.isEmpty) return toast('نام و حداقل یک مرحله لازم است');
        if (e != null) {
          e.name = nm;
          e.steps = steps;
        } else {
          app.tpls.add(Tpl(uid(), nm, steps));
        }
        app.save();
        Navigator.pop(bc);
        toast('قالب ذخیره شد');
      }

      return sheetBody(bc, [
        sheetHead(bc, e != null ? 'ویرایش قالب' : 'قالب جدید'),
        lbl('نام قالب'),
        field(nc, 'مثلاً: پروسه ویدیو کلاس'),
        lbl('مراحل ثابت (به ترتیب)'),
        ReorderableListView(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), buildDefaultDragHandles: false,
          onReorder: (o, n) => set(() {
            if (n > o) n--;
            final x = cs.removeAt(o);
            cs.insert(n, x);
          }),
          children: [
            for (int i = 0; i < cs.length; i++)
              Container(
                key: ObjectKey(cs[i]),
                color: pal.card,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  ReorderableDragStartListener(index: i, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.drag_handle, color: pal.mut))),
                  Expanded(child: field(cs[i], 'مرحله ${i + 1}')),
                  tap(() => set(() => cs.removeAt(i)), Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close, size: 18, color: pal.red))),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 6),
        tap(() => set(() => cs.add(TextEditingController())), Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 11), decoration: BoxDecoration(border: Border.all(color: pal.acc), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: tx('+ افزودن مرحله', color: pal.acc))),
        const SizedBox(height: 16),
        btn('ذخیره قالب', save, bg: pal.acc, fg: Colors.white, wide: true),
        if (e != null) ...[
          const SizedBox(height: 8),
          btn('حذف قالب', () async {
            if (await confirm(bc, 'حذف این قالب؟', e.name)) {
              app.tpls.removeWhere((p) => p.id == e.id);
              app.save();
              if (bc.mounted) Navigator.pop(bc);
              toast('قالب حذف شد');
            }
          }, fg: pal.red, wide: true),
        ],
      ]);
    }),
  );
}

// ============================================================
// تب تقویم
// ============================================================
class CalTab extends StatefulWidget {
  const CalTab({super.key});
  @override
  State<CalTab> createState() => _CalState();
}

class _CalState extends State<CalTab> with SingleTickerProviderStateMixin {
  late final AnimationController ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 340), value: 1);
  String date = today(), prev = today();
  bool week = false, prevWeek = false;
  int sh = 1, stepD = 0; // sh: جهت حرکت (+۱ = جلو)، stepD: تعداد خانه‌هایی که نوار روزها شیفت می‌خورد

  @override
  void dispose() {
    ac.dispose();
    super.dispose();
  }

  double get ease => Curves.easeOutCubic.transform(ac.value);

  String wStart(String d) => addD(d, -((wd(d) + 1) % 7));

  void move(String nd) {
    if (nd == date) return;
    final dd = (pd(nd).difference(pd(date)).inHours / 24).round();
    setState(() {
      prev = date;
      prevWeek = week;
      date = nd;
      sh = dd > 0 ? 1 : -1;
      stepD = week ? 0 : dd.clamp(-3, 3).toInt();
    });
    ac.forward(from: 0);
  }

  void step(int n) => move(addD(date, n * (week ? 7 : 1)));

  void setMode(bool wk, {String? selected}) {
    if (week == wk && selected == null) return;
    ac.value = 1;
    setState(() {
      date = selected ?? date;
      week = wk;
      prev = date;
      prevWeek = wk;
    });
  }

  Widget segBtn(String l, bool on, VoidCallback f) => tap(f, Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7), decoration: BoxDecoration(color: on ? pal.acc : pal.card2, borderRadius: BorderRadius.circular(12)), child: tx(l, size: 13, color: on ? Colors.white : pal.mut)));

  // یک خانه از نوار روزها؛ هرچه به وسط نزدیک‌تر باشد پررنگ‌تر (انتخاب‌شده) می‌شود
  Widget stripCell(String x, int k, double w, double off) {
    final T = today();
    final f = (1 - (-k + off / w).abs()).clamp(0.0, 1.0).toDouble();
    final bg = Color.lerp(pal.card, pal.acc, f)!;
    final nameC = Color.lerp(pal.mut, Colors.white, f)!;
    final numC = Color.lerp(x == T ? pal.acc : pal.tx, Colors.white, f)!;
    final dotC = Color.lerp(pal.acc, Colors.white, f)!;
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: tap(
          () => move(x),
          Container(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              FittedBox(fit: BoxFit.scaleDown, child: tx(DN[wd(x)], size: 10, color: nameC)),
              tx('${jl(x)[2]}', size: 16, w: FontWeight.bold, color: numC),
              Text(itemsOn(x).isNotEmpty ? '●' : ' ', style: TextStyle(fontSize: 8, color: dotC)),
            ]),
          ),
        ),
      ),
    );
  }

  // نوار ۷ روزه: مثل یک قطار شیفت می‌خورد و روز جدید به وسط می‌رسد
  Widget strip() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: LayoutBuilder(builder: (c, bc) {
          final w = bc.maxWidth / 7;
          return SizedBox(
            height: 66,
            child: AnimatedBuilder(
              animation: ac,
              builder: (c, _) {
                final off = -stepD * w * (1 - ease);
                return ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.center,
                    minWidth: 9 * w,
                    maxWidth: 9 * w,
                    child: Transform.translate(
                      offset: Offset(off, 0),
                      child: Row(children: [for (int k = -4; k <= 4; k++) stripCell(addD(date, k), k, w, off)]),
                    ),
                  ),
                );
              },
            ),
          );
        }),
      );

  Widget weekRow(Item w, String x, VoidCallback go) {
    final t = w.t, n = t.subs.length, cnt = t.subs.where((q) => q.done).length;
    final dn = w.k == 'mdone' || (w.k == 'live' && t.completed), od = w.k == 'live' && !t.completed && x.compareTo(today()) < 0;
    return tap(
      go,
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(width: 46, child: tx(tmOf(t).isEmpty ? '—' : tmOf(t), size: 12, color: od ? pal.red : pal.mut)),
          Expanded(child: tx(t.title, size: 14, color: dn ? pal.mut : null, deco: dn ? TextDecoration.lineThrough : null)),
          if (n > 0) tx('$cnt/$n', size: 12, color: pal.amb),
          const SizedBox(width: 6),
          tx(dn ? '✓' : od ? '⚠️' : isRec(t) ? '🔁' : '', size: 13),
        ]),
      ),
    );
  }

  Widget weekDay(String x) {
    final it = itemsOn(x);
    void go() => setMode(false, selected: x);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(16), border: x == today() ? Border.all(color: pal.acc, width: 2) : null),
      child: Column(children: [
        tap(go, Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [tx('${DN[wd(x)]} ${jfmt(x)}', size: 14), tx(it.isEmpty ? '—' : '${it.length} تسک', size: 12, color: pal.mut)]))),
        Container(height: 1, color: pal.bd),
        for (final w in it) weekRow(w, x, go),
      ]),
    );
  }

  Widget dayBody(BuildContext c, String d) {
    final T = today(), it = itemsOn(d);
    final lv = [for (final x in it) if (x.k == 'live') x.t];
    final mn = [for (final x in it) if (x.k != 'live') x];
    final out = <Widget>[];
    if (d == T) {
      final ov = app.tasks.where((t) => !t.completed && t.due.compareTo(T) < 0).toList()..sort((a, b) => a.due != b.due ? a.due.compareTo(b.due) : byTime(a, b));
      final act = lv.where((t) => !t.completed).toList();
      final pr = act.where((t) => st(t) == 'prog').toList(), nw = act.where((t) => st(t) != 'prog').toList();
      final dn = <Widget>[for (final t in lv.where((t) => t.completed)) taskCard(c, t, cls: 'done'), for (final x in mn) mini(x)];
      if (ov.isNotEmpty) {
        out.add(secH('عقب‌افتاده', pal.red, ov.length));
        out.addAll(ov.map((t) => taskCard(c, t, cls: 'over')));
      }
      if (pr.isNotEmpty) {
        out.add(secH('در حال انجام', pal.amb, pr.length));
        out.addAll(pr.map((t) => taskCard(c, t, cls: 'prog')));
      }
      if (nw.isNotEmpty) {
        out.add(secH('کارهای امروز', pal.acc, nw.length));
        out.addAll(nw.map((t) => taskCard(c, t)));
      }
      if (dn.isNotEmpty) {
        out.add(secH('انجام‌شده / برنامه‌ی امروز', pal.grn, dn.length));
        out.addAll(dn);
      }
    } else {
      out.addAll(lv.map((t) => taskCard(c, t, cls: t.completed ? 'done' : (t.due.compareTo(T) < 0 ? 'over' : (st(t) == 'prog' ? 'prog' : '')))));
      out.addAll(mn.map(mini));
    }
    return out.isEmpty ? emptyBox('📭\nبرای این روز تسکی نیست.') : Column(children: out);
  }

  String titleOf(String d, bool wk) {
    final ws = wStart(d), we = addD(ws, 6);
    return wk ? '${jfmt(ws)} تا ${jfmt(we)}' : '${DN[wd(d)]} ${jfmt(d)} ${jl(d)[0]}';
  }

  // تاریخ بین دو فلش: قدیمی به یک سمت می‌رود و غیب می‌شود، جدید جایش می‌آید
  Widget titleWin() => LayoutBuilder(builder: (c, bc) {
        final W = bc.maxWidth;
        return SizedBox(
          height: 26,
          child: AnimatedBuilder(
            animation: ac,
            builder: (c, _) {
              final e = ease;
              Widget lab(String s, double dx, double op) => Opacity(
                    opacity: op.clamp(0.0, 1.0).toDouble(),
                    child: Transform.translate(offset: Offset(dx, 0), child: Center(child: tx(s, w: FontWeight.bold, align: TextAlign.center))),
                  );
              return ClipRect(
                child: Stack(children: [
                  Positioned.fill(child: lab(titleOf(date, week), -sh * W * (1 - e), e)),
                  if (e < 1) Positioned.fill(child: lab(titleOf(prev, prevWeek), sh * W * e, 1 - e)),
                ]),
              );
            },
          ),
        );
      });

  Widget bodyOf(BuildContext c, String d, bool wk) => wk ? Column(children: [for (int i = 0; i < 7; i++) weekDay(addD(wStart(d), i))]) : dayBody(c, d);

  // فقط بخش تسک‌ها با تسک‌های روز بعد/قبل جابه‌جا می‌شود
  Widget content(BuildContext c) => LayoutBuilder(builder: (c2, bc) {
        final W = bc.maxWidth;
        return AnimatedBuilder(
          animation: ac,
          builder: (c3, _) {
            final e = ease;
            final cur = bodyOf(c, date, week);
            if (e >= 1) return cur;
            return ClipRect(
              child: Stack(children: [
                Transform.translate(offset: Offset(-sh * W * (1 - e), 0), child: Opacity(opacity: e, child: SizedBox(width: W, child: cur))),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Transform.translate(offset: Offset(sh * W * e, 0), child: Opacity(opacity: 1 - e, child: bodyOf(c, prev, prevWeek))),
                ),
              ]),
            );
          },
        );
      });

  @override
  Widget build(BuildContext c) {
    final T = today(), ws = wStart(date), we = addD(ws, 6);
    final away = week ? (T.compareTo(ws) < 0 || T.compareTo(we) > 0) : date != T;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() > 300) step(v > 0 ? 1 : -1); // کشیدن از چپ به راست = جلو
      },
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 110), children: [
        Row(children: [
          tx('تقویم', size: 22, w: FontWeight.bold),
          const SizedBox(width: 14),
          segBtn('روز', !week, () => setMode(false)),
          const SizedBox(width: 6),
          segBtn('هفته', week, () => setMode(true)),
        ]),
        if (!week) strip() else const SizedBox(height: 12),
        Row(children: [
          ib(glyph('‹'), () => step(-1)),
          Expanded(
            child: Column(children: [
              titleWin(),
              if (away)
                Padding(padding: const EdgeInsets.only(top: 4), child: btn('برگرد به امروز', () => move(T), p: const EdgeInsets.symmetric(horizontal: 12, vertical: 3)))
              else
                tx(week ? 'هفته‌ی جاری' : 'امروز', size: 12, color: pal.mut),
            ]),
          ),
          ib(glyph('›'), () => step(1)),
        ]),
        const SizedBox(height: 4),
        content(c),
      ]),
    );
  }
}

// ============================================================
// تب همه تسک‌ها
// ============================================================
class AllTab extends StatefulWidget {
  const AllTab({super.key});
  @override
  State<AllTab> createState() => _AllState();
}

class _AllState extends State<AllTab> {
  String fil = 'all';

  Widget dvd(String label, {Color? col, bool big = false}) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(children: [
          Expanded(child: Container(height: 1, color: (col ?? pal.bd).withOpacity(col != null ? .5 : 1))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: tx(label, size: big ? 14 : 13, w: big ? FontWeight.bold : null, color: col ?? (big ? pal.tx : pal.mut))),
          Expanded(child: Container(height: 1, color: (col ?? pal.bd).withOpacity(col != null ? .5 : 1))),
        ]),
      );

  List<List<dynamic>> grp(List<Task> a, {bool desc = false}) {
    final m = <String, List<Task>>{};
    for (final t in a) {
      (m[t.due] ??= []).add(t);
    }
    final keys = m.keys.toList()..sort((x, y) => desc ? y.compareTo(x) : x.compareTo(y));
    return [for (final k in keys) [k, (m[k]!..sort(byTime))]];
  }

  @override
  Widget build(BuildContext c) {
    final T = today();
    bool f(Task t) => fil == 'all' ? true : fil == 'normal' ? !isRec(t) : fil == 'rec' ? isRec(t) : t.completed;
    final L = app.tasks.where(f).where((t) => fil == 'done' || !t.completed).toList();
    final act = L.where((t) => !t.completed).toList(), dn = L.where((t) => t.completed).toList();
    final doneDates = <String, List<Item>>{};
    for (final t in dn) {
      (doneDates[t.due] ??= []).add(Item(t, 'live', t.due));
    }
    if (fil == 'done') {
      for (final t in app.tasks.where(isRec)) {
        for (final d in t.log.toSet()) {
          (doneDates[d] ??= []).add(Item(t, 'mdone', d));
        }
      }
    }
    final completedDays = doneDates.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final entries in doneDates.values) {
      entries.sort((a, b) => byTime(a.t, b.t));
    }
    final od = act.where((t) => t.due.compareTo(T) < 0).toList(), up = act.where((t) => t.due.compareTo(T) >= 0).toList();
    Widget fr(Task t) => taskCard(c, t, cls: t.completed ? 'done' : (t.due.compareTo(T) < 0 ? 'over' : (st(t) == 'prog' ? 'prog' : '')));
    String dl(String k) => '${k == T ? 'امروز · ' : ''}${DN[wd(k)]} ${jfmt(k)}${jl(k)[0] != jl(T)[0] ? ' ${jl(k)[0]}' : ''}';
    const ch = [['all', 'همه'], ['normal', 'عادی'], ['rec', 'تکرارشونده / روتین'], ['done', 'انجام‌شده']];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 110), children: [
      tx('همه تسک‌ها', size: 22, w: FontWeight.bold),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final x in ch) chip(x[1], fil == x[0], () => setState(() => fil = x[0]))]),
      if (od.isNotEmpty) ...[
        dvd('⚠️ از موعد گذشته', col: pal.red, big: true),
        for (final g in grp(od)) ...[dvd(dl(g[0] as String), col: pal.red), ...(g[1] as List<Task>).map(fr)],
      ],
      for (final g in grp(up)) ...[dvd(dl(g[0] as String)), ...(g[1] as List<Task>).map(fr)],
      if (completedDays.isNotEmpty) ...[
        dvd('✓ انجام‌شده', big: true),
        for (final d in completedDays) ...[
          dvd(dl(d)),
          for (final item in doneDates[d]!) item.k == 'mdone' ? mini(item) : fr(item.t),
        ],
      ],
      if (L.isEmpty && completedDays.isEmpty) emptyBox('موردی نیست.'),
    ]);
  }
}

// ============================================================
// تب قالب‌ها
// ============================================================
class TplTab extends StatelessWidget {
  const TplTab({super.key});
  @override
  Widget build(BuildContext c) => ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 110), children: [
        tx('قالب‌ها', size: 22, w: FontWeight.bold),
        tx('مراحل ثابت کارهای تکراری را یک‌بار بساز و هر جا خواستی استفاده کن.', size: 13, color: pal.mut),
        const SizedBox(height: 14),
        for (final p in app.tpls)
          tap(
            () => openTplForm(c, edit: p),
            cardBox(
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [tx(p.name, w: FontWeight.bold), tx(p.steps.join(' ← '), size: 12, color: pal.mut)])),
                Icon(Icons.edit, size: 18, color: pal.mut),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        btn('+ قالب جدید', () => openTplForm(c), bg: pal.acc, fg: Colors.white, wide: true),
      ]);
}

// ============================================================
// تب تنظیمات و پشتیبان‌گیری
// ============================================================
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
    app.save();
    toast('اطلاعات بازگردانی شد ✓');
  } catch (_) {
    toast('فایل پشتیبان معتبر نیست');
  }
}

class SetTab extends StatelessWidget {
  const SetTab({super.key});
  @override
  Widget build(BuildContext c) => ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 110), children: [
        tx('تنظیمات', size: 22, w: FontWeight.bold),
        const SizedBox(height: 14),
        cardBox(
          child: Row(children: [
            Expanded(child: tx('حالت تاریک', w: FontWeight.bold)),
            Switch(value: app.dark, activeColor: pal.acc, onChanged: (v) {
              app.dark = v;
              app.save();
            }),
          ]),
        ),
        cardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            tx('پشتیبان‌گیری و بازگردانی', w: FontWeight.bold),
            const SizedBox(height: 4),
            tx('فایل JSON می‌سازد و با «اشتراک‌گذاری» می‌توانی آن را در فایل‌های گوشی، تلگرام یا Drive ذخیره کنی.', size: 12, color: pal.mut),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [btn('⬇ ساخت فایل پشتیبان', exportBackup), btn('⬆ بازگردانی از فایل', () => importBackup(c))]),
          ]),
        ),
        cardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            tx('یادآوری‌ها', w: FontWeight.bold),
            const SizedBox(height: 4),
            tx('اگر یادآورها با تأخیر آمدند، در تنظیمات گوشی «بهینه‌سازی باتری» را برای این برنامه روی «بدون محدودیت» بگذار.', size: 12, color: pal.mut),
          ]),
        ),
        cardBox(
          child: btn('حذف همه اطلاعات', () async {
            if (await confirm(c, 'حذف همه اطلاعات؟', 'همه تسک‌ها و قالب‌ها')) {
              app.seed();
              app.save();
              toast('همه اطلاعات پاک شد');
            }
          }, fg: pal.red),
        ),
      ]);
}

// ============================================================
// صفحه اصلی و شروع برنامه
// ============================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomeState();
}

class _HomeState extends State<HomePage> with WidgetsBindingObserver {
  int tab = 0, calReset = 0;
  Timer? tk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tk = Timer.periodic(const Duration(seconds: 1), (_) => app.tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => askPerms());
  }

  @override
  void dispose() {
    tk?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) app.load();
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: app,
        builder: (c, _) {
          final pages = <Widget>[CalTab(key: ValueKey('cal$calReset')), AllTab(), TplTab(), SetTab()];
          const ics = [Icons.calendar_month, Icons.checklist, Icons.view_list, Icons.settings];
          const lbs = ['تقویم', 'همه تسک‌ها', 'قالب‌ها', 'تنظیمات'];
          return Scaffold(
            backgroundColor: pal.bg,
            body: SafeArea(bottom: false, child: pages[tab]),
            floatingActionButton: tab < 2 ? FloatingActionButton(onPressed: () => openTaskForm(c), backgroundColor: pal.acc, foregroundColor: Colors.white, child: const Icon(Icons.add, size: 30)) : null,
            bottomNavigationBar: Container(
              color: pal.card,
              child: SafeArea(
                top: false,
                child: Row(children: [
                  for (int i = 0; i < 4; i++)
                    Expanded(
                      child: tap(
                        () => setState(() {
                          if (i == 0 && tab == 0) calReset++;
                          tab = i;
                        }),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(ics[i], color: tab == i ? pal.acc : pal.mut), tx(lbs[i], size: 11, color: tab == i ? pal.acc : pal.mut)])),
                      ),
                    ),
                ]),
              ),
            ),
          );
        },
      );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: app,
        builder: (c, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: msgKey,
          title: 'وظایف من',
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Vazirmatn',
            scaffoldBackgroundColor: pal.bg,
            colorScheme: ColorScheme.fromSeed(seedColor: pal.acc, brightness: app.dark ? Brightness.dark : Brightness.light),
          ),
          home: const HomePage(),
        ),
      );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotif();
  await app.load();
  runApp(const MyApp());
}
