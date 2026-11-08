import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/src/models.dart';

void main() {
  group('Models Serialization and Integrity', () {
    test('Sub serializes to and from JSON correctly', () {
      final sub = Sub('s1', 'خرید میوه', done: true, tp: 't1');
      final json = sub.toJson();
      final revived = Sub.fromJson(json);

      expect(revived.id, equals('s1'));
      expect(revived.t, equals('خرید میوه'));
      expect(revived.done, isTrue);
      expect(revived.tp, equals('t1'));
    });

    test('Alarm serializes to and from JSON correctly', () {
      final alarm = Alarm(
        type: 'weekly',
        time: '14:30',
        date: '2026-11-08',
        days: [0, 6],
        doms: [1, 15],
      );
      final json = alarm.toJson();
      final revived = Alarm.fromJson(json);

      expect(revived.type, equals('weekly'));
      expect(revived.time, equals('14:30'));
      expect(revived.date, equals('2026-11-08'));
      expect(revived.days, equals([0, 6]));
      expect(revived.doms, equals([1, 15]));
    });

    test('Task serializes to and from JSON accurately', () {
      final task = Task(
        id: 't100',
        title: 'پروژه جدید',
        note: 'توضیحات تکمیلی پروژه',
        due: '2026-11-10',
        created: '2026-11-08',
        completed: false,
        tpl: 'tpl1',
        subs: [Sub('sub1', 'مرحله ۱', done: true)],
        alarm: Alarm(type: 'daily', time: '08:00'),
        log: ['2026-11-07'],
        skipped: ['2026-11-06'],
      );

      final json = task.toJson();
      final revived = Task.fromJson(json);

      expect(revived.id, equals('t100'));
      expect(revived.title, equals('پروژه جدید'));
      expect(revived.note, equals('توضیحات تکمیلی پروژه'));
      expect(revived.due, equals('2026-11-10'));
      expect(revived.completed, isFalse);
      expect(revived.tpl, equals('tpl1'));
      expect(revived.subs.length, equals(1));
      expect(revived.subs.first.t, equals('مرحله ۱'));
      expect(revived.alarm.type, equals('daily'));
      expect(revived.log, equals(['2026-11-07']));
      expect(revived.skipped, equals(['2026-11-06']));
    });

    test('Task.clone creates an independent deep copy', () {
      final original = Task(
        id: 't1',
        title: 'اصلی',
        subs: [Sub('s1', 'زیرکار', done: false)],
        alarm: Alarm(time: '10:00'),
      );

      final clone = original.clone();
      expect(clone.id, equals(original.id));
      expect(clone.title, equals(original.title));

      // Mutating clone should not mutate original
      clone.title = 'تغییر یافته';
      clone.subs.first.done = true;
      clone.alarm.time = '12:00';

      expect(original.title, equals('اصلی'));
      expect(original.subs.first.done, isFalse);
      expect(original.alarm.time, equals('10:00'));
    });

    test('Reminder serializes and clones correctly', () {
      final reminder = Reminder(
        id: 'r1',
        title: 'پرداخت قسط',
        note: 'شماره کارت ۱۲۳۴',
        date: '2026-11-20',
        time: '10:00',
        offsets: [15, 60],
      );

      final json = reminder.toJson();
      final revived = Reminder.fromJson(json);

      expect(revived.id, equals('r1'));
      expect(revived.title, equals('پرداخت قسط'));
      expect(revived.note, equals('شماره کارت ۱۲۳۴'));
      expect(revived.date, equals('2026-11-20'));
      expect(revived.time, equals('10:00'));
      expect(revived.offsets, equals([15, 60]));

      final clone = reminder.clone();
      clone.title = 'کلون شده';
      expect(reminder.title, equals('پرداخت قسط'));
    });

    test('Tpl serializes to and from JSON', () {
      final tpl = Tpl('tp1', 'قالب روزمره', ['گام ۱', 'گام ۲', 'گام ۳']);
      final json = tpl.toJson();
      final revived = Tpl.fromJson(json);

      expect(revived.id, equals('tp1'));
      expect(revived.name, equals('قالب روزمره'));
      expect(revived.steps, equals(['گام ۱', 'گام ۲', 'گام ۳']));
    });
  });
}
