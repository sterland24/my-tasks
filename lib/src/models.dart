import 'dart:convert';
import 'jalali.dart';

// ============================================================
// مدل‌های داده
// ============================================================
class Sub {
  String id, t;
  bool done;
  String? tp;
  Sub(this.id, this.t, {this.done = false, this.tp});
  Map<String, dynamic> toJson() => {'id': id, 't': t, 'done': done, 'tp': tp};
  factory Sub.fromJson(Map<String, dynamic> j) => Sub(
        j['id'] as String,
        j['t'] as String,
        done: j['done'] == true,
        tp: j['tp'] as String?,
      );
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
  List<String> skipped;
  String? tpl;
  Task({
    required this.id,
    required this.title,
    this.note = '',
    List<Sub>? subs,
    Alarm? alarm,
    String? due,
    this.completed = false,
    String? created,
    List<String>? log,
    List<String>? skipped,
    this.tpl,
  })  : subs = subs ?? [],
        alarm = alarm ?? Alarm(),
        due = due ?? today(),
        created = created ?? today(),
        log = log ?? [],
        skipped = skipped ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'due': due,
        'created': created,
        'completed': completed,
        'tpl': tpl,
        'subs': subs.map((s) => s.toJson()).toList(),
        'alarm': alarm.toJson(),
        'log': log,
        'skipped': skipped,
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
        skipped: ((j['skipped'] ?? []) as List).map((e) => e.toString()).toList(),
      );

  Task clone() => Task.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(toJson())) as Map));
}

class Reminder {
  String id, title, note, date, time;
  List<int> offsets;
  Reminder({
    required this.id,
    required this.title,
    this.note = '',
    required this.date,
    this.time = '09:00',
    List<int>? offsets,
  }) : offsets = offsets ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'date': date,
        'time': time,
        'offsets': offsets,
      };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] as String,
        title: j['title'] as String,
        note: (j['note'] ?? '') as String,
        date: j['date'] as String,
        time: (j['time'] ?? '09:00') as String,
        offsets: ((j['offsets'] ?? []) as List).map((e) => (e as num).toInt()).toList(),
      );

  Reminder clone() => Reminder.fromJson(Map<String, dynamic>.from(jsonDecode(jsonEncode(toJson())) as Map));
}

class Tpl {
  String id, name;
  List<String> steps;
  Tpl(this.id, this.name, this.steps);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'steps': steps};
  factory Tpl.fromJson(Map<String, dynamic> j) => Tpl(
        j['id'] as String,
        j['name'] as String,
        ((j['steps'] ?? []) as List).map((e) => e.toString()).toList(),
      );
}

class Item {
  final Task t;
  final String k, d; // k: live | mdone | plan
  Item(this.t, this.k, this.d);
}
