import 'dart:math';

import 'jalali.dart';
import 'models.dart';

// ============================================================
// منطق تسک‌ها و تکرار
// ============================================================

/// فهرست مرتب‌شده روزهای ماه آلارم
List<int> daysOfMonthOf(Alarm a) => ([...a.doms]..sort());
List<int> domsOf(Alarm a) => daysOfMonthOf(a);

/// ساعت آلارم تسک یا رشته خالی
String timeOf(Task t) => t.alarm.type != 'none' ? t.alarm.time : '';
String tmOf(Task t) => timeOf(t);

/// ساعت فعلی به فرمت HH:mm
String currentTimeString() {
  final d = DateTime.now();
  return '${padTwoDigits(d.hour)}:${padTwoDigits(d.minute)}';
}
String nowT() => currentTimeString();

/// آیا تسک تکرارشونده است؟
bool isRecurringTask(Task t) => t.alarm.type == 'daily' || t.alarm.type == 'weekly' || t.alarm.type == 'monthly';
bool isRec(Task t) => isRecurringTask(t);

/// آیا موعد انجام تسک گذشته است؟
bool isTaskLate(Task t) => !t.completed && t.due == today() && timeOf(t).isNotEmpty && timeOf(t).compareTo(currentTimeString()) < 0;
bool late(Task t) => isTaskLate(t);

/// وضعیت تسک: 'done' | 'prog' | 'new'
String taskStatus(Task t) {
  if (t.completed) return 'done';
  final c = t.subs.where((s) => s.done).length;
  return (c > 0 && c < t.subs.length) ? 'prog' : 'new';
}
String st(Task t) => taskStatus(t);

/// مقایسه و مرتب‌سازی تسک‌ها بر اساس ساعت
int compareTasksByTime(Task a, Task b) => (timeOf(a).isEmpty ? '99:99' : timeOf(a)).compareTo(timeOf(b).isEmpty ? '99:99' : timeOf(b));
int byTime(Task a, Task b) => compareTasksByTime(a, b);

/// پیدا کردن تاریخ بزرگ‌تر (جدیدتر)
String maxDate(String a, String b) => a.compareTo(b) > 0 ? a : b;
String mx(String a, String b) => maxDate(a, b);

/// پیدا کردن نوبت بعدی وقوع بر اساس قاعده تکرار
String nextOccurrence(Alarm a, String start) {
  if (a.type == 'daily') return start;
  if (a.type == 'weekly') {
    for (int i = 0; i < 8; i++) {
      final d = addDays(start, i);
      if (a.days.contains(weekdayOf(d))) return d;
    }
    return start;
  }
  final dl = daysOfMonthOf(a);
  final j = parseJalaliDate(start);
  int y = j[0], m = j[1];
  for (int k = 0; k < 3; k++) {
    final c = dl.map((d) => jalaliToDateString(y, m, d)).where((x) => x.compareTo(start) >= 0).toList()..sort();
    if (c.isNotEmpty) return c.first;
    m++;
    if (m > 12) {
      m = 1;
      y++;
    }
  }
  return start;
}
String nextOcc(Alarm a, String start) => nextOccurrence(a, start);

/// پیدا کردن اولین نوبت باز که هنوز انجام نشده یا رد نشده باشد
String nextOpenDate(Task t, String start) {
  String d = nextOccurrence(t.alarm, start);
  int i = 0;
  while ((t.log.contains(d) || t.skipped.contains(d)) && i++ < 400) {
    d = nextOccurrence(t.alarm, addDays(d, 1));
  }
  return d;
}
String nextOpen(Task t, String start) => nextOpenDate(t, start);

/// آیا این تسک در تاریخ مشخص رخ می‌دهد؟
bool taskOccursOnDate(Task t, String d) {
  final a = t.alarm;
  if (d.compareTo(t.created) < 0 || t.skipped.contains(d)) return false;
  if (a.type == 'daily') return true;
  if (a.type == 'weekly') return a.days.contains(weekdayOf(d));
  if (a.type == 'monthly') {
    final j = parseJalaliDate(d);
    return daysOfMonthOf(a).any((x) => min(x, jalaliMonthLength(j[1], j[0])) == j[2]);
  }
  return false;
}
bool occurs(Task t, String d) => taskOccursOnDate(t, d);

/// علامت‌گذاری تسک به عنوان انجام‌شده
void completeTask(Task t) {
  if (isRecurringTask(t)) {
    t.log.add(t.due);
    t.due = nextOpenDate(t, maxDate(addDays(t.due, 1), today()));
    for (final s in t.subs) {
      s.done = false;
    }
  } else {
    t.completed = true;
  }
}

/// متن توضیحی آلارم و تکرار تسک
String formatAlarmText(Alarm a) {
  if (a.type == 'once') return '🔔 ${formatJalaliDate(a.date)} ساعت ${a.time}';
  if (a.type == 'daily') return '🔁 هر روز ${a.time}';
  if (a.type == 'weekly') return '🔁 ${jalaliWeekOrder.where((d) => a.days.contains(d)).map((d) => jalaliDayNames[d]).join('، ')} ${a.time}';
  if (a.type == 'monthly') return '🔁 روزهای ${daysOfMonthOf(a).join('، ')} هر ماه ${a.time}';
  return '';
}
String alarmTxt(Alarm a) => formatAlarmText(a);

/// ترکیب تاریخ و زمان به DateTime
DateTime dateTimeAtTime(String d, String time) {
  final p = time.split(':');
  final x = parseDate(d);
  return DateTime(x.year, x.month, x.day, int.parse(p[0]), int.parse(p[1]));
}
DateTime atTime(String d, String time) => dateTimeAtTime(d, time);

/// تولید شناسه هش ۳۰ بیتی برای نوتیفیکیشن
int notificationId(String s) {
  int h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0x3fffffff;
  }
  return h;
}
int nid(String s) => notificationId(s);
