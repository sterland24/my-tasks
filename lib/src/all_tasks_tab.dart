import 'package:flutter/material.dart';

import 'app_state.dart';
import 'jalali.dart';
import 'models.dart';
import 'task_logic.dart';
import 'ui_helpers.dart';

// ============================================================
// تب همه تسک‌ها (فیلترهای همه، عادی، روتین و انجام‌شده)
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
          Expanded(child: Container(height: 1, color: (col ?? pal.bd).withValues(alpha: col != null ? .5 : 1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: tx(label, size: big ? 14 : 13, w: big ? FontWeight.bold : null, color: col ?? (big ? pal.tx : pal.mut)),
          ),
          Expanded(child: Container(height: 1, color: (col ?? pal.bd).withValues(alpha: col != null ? .5 : 1))),
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
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: app,
        builder: (c, _) {
          final T = today();
          bool f(Task t) => fil == 'all' ? true : fil == 'normal' ? !isRecurringTask(t) : fil == 'rec' ? isRecurringTask(t) : t.completed;
          final L = app.tasks.where(f).where((t) => fil == 'done' || !t.completed).toList();
          final act = L.where((t) => !t.completed).toList(), dn = L.where((t) => t.completed).toList();
          final doneDates = <String, List<Item>>{};
          for (final t in dn) {
            (doneDates[t.due] ??= []).add(Item(t, 'live', t.due));
          }
          if (fil == 'done') {
            for (final t in app.tasks.where(isRecurringTask)) {
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
          Widget fr(BuildContext ctx, Task t) =>
              taskCard(ctx, t, cls: t.completed ? 'done' : (t.due.compareTo(T) < 0 ? 'over' : (taskStatus(t) == 'prog' ? 'prog' : '')));
          String dl(String k) => '${k == T ? 'امروز · ' : ''}${DN[weekdayOf(k)]} ${formatJalaliDate(k)}${parseJalaliDate(k)[0] != parseJalaliDate(T)[0] ? ' ${parseJalaliDate(k)[0]}' : ''}';
          const ch = [
            ['all', 'همه'],
            ['normal', 'عادی'],
            ['rec', 'تکرارشونده / روتین'],
            ['done', 'انجام‌شده'],
          ];

          final rows = <Widget Function(BuildContext)>[
            (_) => tx('همه تسک‌ها', size: 22, w: FontWeight.bold),
            (_) => const SizedBox(height: 10),
            (_) => Wrap(spacing: 8, runSpacing: 8, children: [for (final x in ch) chip(x[1], fil == x[0], () => setState(() => fil = x[0]))]),
          ];

          if (fil == 'all' && app.reminders.isNotEmpty) {
            final reminders = [...app.reminders]..sort((a, b) {
                final dateOrder = a.date.compareTo(b.date);
                return dateOrder != 0 ? dateOrder : a.time.compareTo(b.time);
              });
            rows.add((_) => dvd('🔔 یادآوری‌ها', col: pal.amb, big: true));
            for (final r in reminders) {
              rows.add((ctx) => reminderCard(ctx, r));
            }
          }

          if (od.isNotEmpty) {
            rows.add((_) => dvd('⚠️ از موعد گذشته', col: pal.red, big: true));
            for (final g in grp(od)) {
              final k = g[0] as String;
              final list = g[1] as List<Task>;
              rows.add((_) => dvd(dl(k), col: pal.red));
              for (final t in list) {
                rows.add((ctx) => fr(ctx, t));
              }
            }
          }
          for (final g in grp(up)) {
            final k = g[0] as String;
            final list = g[1] as List<Task>;
            rows.add((_) => dvd(dl(k)));
            for (final t in list) {
              rows.add((ctx) => fr(ctx, t));
            }
          }
          if (completedDays.isNotEmpty) {
            rows.add((_) => dvd('✓ انجام‌شده', big: true));
            for (final d in completedDays) {
              rows.add((_) => dvd(dl(d)));
              for (final item in doneDates[d]!) {
                rows.add((ctx) => item.k == 'mdone' ? mini(item) : fr(ctx, item.t));
              }
            }
          }
          if (L.isEmpty && completedDays.isEmpty && (fil != 'all' || app.reminders.isEmpty)) {
            rows.add((_) => emptyBox('موردی نیست.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
            itemCount: rows.length,
            itemBuilder: (ctx, i) => rows[i](ctx),
          );
        },
      );
}
