import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/main.dart';

Widget host(Widget child) => MaterialApp(
  locale: const Locale('fa'),
  supportedLocales: const [Locale('fa')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

void main() {
  setUp(() {
    app.tasks.clear();
    app.ex.clear();
    app.timers.clear();
  });

  testWidgets('calendar follows the finger and snaps to the next RTL day', (tester) async {
    app.tasks.addAll([
      Task(id: 'today', title: 'current day task'),
      Task(id: 'tomorrow', title: 'next day task', due: addD(today(), 1)),
    ]);
    await tester.pumpWidget(host(const CalTab()));
    final pager = tester.widget<PageView>(find.byType(PageView)).controller!;
    final start = pager.page!;
    final size = tester.getSize(find.byType(PageView));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(PageView)));
    await gesture.moveBy(Offset(size.width * .35, 0));
    await tester.pump();
    expect(pager.page, greaterThan(start));
    expect(pager.page, lessThan(start + 1));
    expect(find.text('current day task'), findsOneWidget);
    expect(find.text('next day task'), findsOneWidget);
    await gesture.moveBy(Offset(size.width * .4, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pager.page, start + 1);

    await tester.drag(find.byType(PageView), Offset(-size.width * .8, 0));
    await tester.pumpAndSettle();
    expect(pager.page, start);
    expect(tester.takeException(), isNull);
  });

  testWidgets('week and day modes preserve the selected day', (tester) async {
    await tester.pumpWidget(host(const CalTab()));
    await tester.tap(find.text('هفته'));
    await tester.pumpAndSettle();
    final pager = tester.widget<PageView>(find.byType(PageView)).controller!;
    final start = pager.page!;
    final size = tester.getSize(find.byType(PageView));
    await tester.drag(find.byType(PageView), Offset(size.width * .8, 0));
    await tester.pumpAndSettle();
    expect(pager.page, start + 1);
    await tester.tap(find.text('روز'));
    await tester.pumpAndSettle();
    final nextWeek = addD(today(), 7);
    expect(find.text(fa('${DN[wd(nextWeek)]} ${jfmt(nextWeek)} ${jl(nextWeek)[0]}')), findsOneWidget);
    await tester.tap(find.text('برگرد به امروز'));
    await tester.pumpAndSettle();
    expect(find.text('برگرد به امروز'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed filter includes each recurring occurrence by its own date', (tester) async {
    final first = addD(today(), -2), second = addD(today(), -1);
    final task = Task(
      id: 'routine', title: 'daily routine',
      alarm: Alarm(type: 'daily'),
      due: first, created: first,
    );
    completeTask(task);
    task.due = second;
    completeTask(task);
    app.tasks.add(Task.fromJson(task.toJson()));
    await tester.pumpWidget(host(const AllTab()));
    await tester.tap(find.text('انجام‌شده'));
    await tester.pumpAndSettle();
    expect(find.text('daily routine'), findsNWidgets(2));
    expect(find.text(fa(jfmt(first))), findsOneWidget);
    expect(find.text(fa(jfmt(second))), findsOneWidget);
    expect(find.text('موردی نیست.'), findsNothing);
    expect(app.tasks.single.completed, isFalse);
    expect(app.tasks.single.due, today());
  });

  testWidgets('no-alarm task saves a chosen date and displays it after completion', (tester) async {
    final selected = fromJ(jl(today())[0], 7, 25);
    app.tasks.add(Task(id: 'silent', title: 'silent task', due: selected));
    await tester.pumpWidget(host(Builder(builder: (context) => TextButton(
      onPressed: () => openTaskForm(context, edit: app.tasks.single),
      child: const Text('edit'),
    ))));
    await tester.tap(find.text('edit'));
    await tester.pumpAndSettle();
    final day = find.byType(DropdownButton<int>).first;
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pumpAndSettle();
    await tester.tap(find.text(fa(26)).last);
    await tester.pumpAndSettle();
    final save = find.text('ذخیره تسک');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final task = app.tasks.single;
    expect(task.due, addD(selected, 1));
    expect(task.alarm.type, 'none');
    expect(tmOf(task), isEmpty);
    completeTask(task);
    await tester.pumpWidget(host(const AllTab()));
    await tester.tap(find.text('انجام‌شده'));
    await tester.pumpAndSettle();
    expect(find.text(fa(jfmt(task.due))), findsOneWidget);
    expect(find.textContaining('🔔'), findsNothing);
    expect(find.textContaining('09:00'), findsNothing);
  });
}
