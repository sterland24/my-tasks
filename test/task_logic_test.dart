import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/src/jalali.dart';
import 'package:task_manager/src/models.dart';
import 'package:task_manager/src/task_logic.dart';

void main() {
  group('Task Recurrence & Status Logic', () {
    test('identifies recurring vs non-recurring tasks', () {
      final oneOff = Task(id: '1', title: 'خرید نان', alarm: Alarm(type: 'once'));
      final none = Task(id: '2', title: 'تماس', alarm: Alarm(type: 'none'));
      final daily = Task(id: '3', title: 'ورزش', alarm: Alarm(type: 'daily'));
      final weekly = Task(id: '4', title: 'جلسه', alarm: Alarm(type: 'weekly', days: [6]));
      final monthly = Task(id: '5', title: 'اجاره', alarm: Alarm(type: 'monthly', doms: [1]));

      expect(isRecurringTask(oneOff), isFalse);
      expect(isRecurringTask(none), isFalse);
      expect(isRecurringTask(daily), isTrue);
      expect(isRecurringTask(weekly), isTrue);
      expect(isRecurringTask(monthly), isTrue);
    });

    test('computes task status correctly (new, prog, done)', () {
      final taskNew = Task(id: '1', title: 'تسک جدید', subs: [
        Sub('s1', 'گام اول', done: false),
        Sub('s2', 'گام دوم', done: false),
      ]);
      expect(taskStatus(taskNew), equals('new'));

      final taskProg = Task(id: '2', title: 'تسک در حال انجام', subs: [
        Sub('s1', 'گام اول', done: true),
        Sub('s2', 'گام دوم', done: false),
      ]);
      expect(taskStatus(taskProg), equals('prog'));

      final taskDone = Task(id: '3', title: 'تسک تمام شده', completed: true);
      expect(taskStatus(taskDone), equals('done'));
    });

    test('daily task occurs every day after creation', () {
      final task = Task(id: '1', title: 'ورزش روزانه', created: '2026-11-01', alarm: Alarm(type: 'daily'));
      expect(taskOccursOnDate(task, '2026-10-31'), isFalse); // before creation
      expect(taskOccursOnDate(task, '2026-11-01'), isTrue);
      expect(taskOccursOnDate(task, '2026-11-05'), isTrue);
    });

    test('weekly task occurs on specified days', () {
      // 2026-11-07 is Saturday (6), 2026-11-08 is Sunday (0)
      final task = Task(
        id: '1',
        title: 'برنامه‌ریزی شنبه',
        created: '2026-11-01',
        alarm: Alarm(type: 'weekly', days: [6]),
      );
      expect(taskOccursOnDate(task, '2026-11-07'), isTrue);
      expect(taskOccursOnDate(task, '2026-11-08'), isFalse);
    });

    test('completing a one-off task marks completed = true', () {
      final task = Task(id: '1', title: 'خرید شارژ', completed: false);
      completeTask(task);
      expect(task.completed, isTrue);
    });

    test('completing a recurring task logs the date and advances due date', () {
      final todayStr = today();
      final task = Task(
        id: '1',
        title: 'پیاده‌روی',
        due: todayStr,
        alarm: Alarm(type: 'daily'),
        subs: [Sub('s1', 'کفش', done: true)],
      );

      completeTask(task);

      // Should not be marked as permanently completed
      expect(task.completed, isFalse);
      // Date should be logged
      expect(task.log, contains(todayStr));
      // Due date should be advanced to future
      expect(task.due.compareTo(todayStr), greaterThan(0));
      // Subtasks should be reset for next round
      expect(task.subs.first.done, isFalse);
    });

    test('skipped occurrences are not considered occurring', () {
      final task = Task(
        id: '1',
        title: 'ورزش',
        created: '2026-11-01',
        alarm: Alarm(type: 'daily'),
        skipped: ['2026-11-05'],
      );
      expect(taskOccursOnDate(task, '2026-11-05'), isFalse);
      expect(taskOccursOnDate(task, '2026-11-06'), isTrue);
    });

    test('generates deterministic notification IDs within safe integer range', () {
      final id1 = notificationId('task|123|2026-11-08');
      final id2 = notificationId('task|123|2026-11-08');
      final id3 = notificationId('task|123|2026-11-09');

      expect(id1, equals(id2));
      expect(id1, isNot(equals(id3)));
      expect(id1, isNonNegative);
      expect(id1, lessThan(0x3fffffff));
    });
  });
}
