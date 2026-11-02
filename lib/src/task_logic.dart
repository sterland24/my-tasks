import 'dart:math';
import 'jalali.dart';
import 'models.dart';

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
    return domsOf(a).any((x) => min(x, mlen(j[1], j[0])) == j[2]);
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
