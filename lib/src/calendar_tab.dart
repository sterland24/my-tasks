import 'package:flutter/material.dart';

import 'app_state.dart';
import 'jalali.dart';
import 'models.dart';
import 'sheets.dart';
import 'task_logic.dart';
import 'ui_helpers.dart';

// ============================================================
// تب تقویم (نمای روز و هفته با انیمیشن قطاری و دیوار نامرئی)
// ============================================================
class CalTab extends StatefulWidget {
  const CalTab({super.key});
  @override
  State<CalTab> createState() => _CalState();
}

class _CalState extends State<CalTab> {
  String date = today();
  bool week = false;
  static const _firstPage = 100000;
  final PageController _pages = PageController(initialPage: _firstPage);
  String _anchor = today();
  int _page = _firstPage;

  @override
  void initState() {
    super.initState();
    app.selectedDate = date;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String pageDate(int index) => addDays(_anchor, (index - _firstPage) * (week ? 7 : 1));

  double get _currentPage =>
      _pages.hasClients && _pages.position.haveDimensions
          ? (_pages.page ?? _page.toDouble())
          : _page.toDouble();

  void showDate(String value) {
    final days = parseDate(value).difference(parseDate(_anchor)).inDays;
    final target = _firstPage + (week ? (days / 7).floor() : days);
    final distance = (target - _page).abs();
    if (distance > 3) {
      _pages.jumpToPage(target > _page ? target - 2 : target + 2);
    }
    _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void showWeek(bool value, {String? selected}) {
    if (week == value) return;
    _pages.jumpToPage(_page);
    setState(() {
      date = selected ?? date;
      app.selectedDate = date;
      week = value;
      _anchor = addDays(date, -(_page - _firstPage) * (week ? 7 : 1));
    });
  }

  String wStart(String d) => addDays(d, -((weekdayOf(d) + 1) % 7));

  void step(int n) => _pages.animateToPage(
        _page + n,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );

  Widget segBtn(String l, bool on, VoidCallback f) => tap(
        f,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(color: on ? pal.acc : pal.card2, borderRadius: BorderRadius.circular(12)),
          child: tx(l, size: 13, color: on ? Colors.white : pal.mut),
        ),
      );

  Widget dayStrip(BuildContext c, double currentPage) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const int visibleSlots = 7;
        final slotWidth = totalWidth / visibleSlots;
        final centerOffset = (totalWidth - slotWidth) / 2.0;

        final minIdx = currentPage.floor() - 4;
        final maxIdx = currentPage.ceil() + 4;
        final T = today();

        return SizedBox(
          height: 68,
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = minIdx; i <= maxIdx; i++) ...[
                  () {
                    final x = pageDate(i);
                    final isToday = x == T;
                    final offsetFromCurrent = i - currentPage;
                    final start = centerOffset + offsetFromCurrent * slotWidth;
                    final dist = offsetFromCurrent.abs();
                    final factor = (1.0 - dist).clamp(0.0, 1.0);

                    final hasItems = itemsOn(x).isNotEmpty || app.remindersOn(x).isNotEmpty;
                    final cardBg = Color.lerp(pal.card, pal.acc, factor)!;
                    final weekdayColor = Color.lerp(pal.mut, Colors.white, factor);
                    final numberColor = Color.lerp(isToday ? pal.acc : pal.tx, Colors.white, factor);
                    final dotColor = Color.lerp(pal.acc, Colors.white, factor);

                    return PositionedDirectional(
                      start: start,
                      width: slotWidth,
                      top: 0,
                      bottom: 0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2),
                        child: tap(
                          () => showDate(x),
                          Transform.scale(
                            scale: 1.0 + 0.04 * factor,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(
                                  app.themeId == 'classic' ? 12 : pal.radius * 0.55,
                                ),
                                border: isToday && factor < 0.8
                                    ? Border.all(
                                        color: pal.acc.withValues(alpha: 0.8 * (1.0 - factor)),
                                        width: 1.5,
                                      )
                                    : null,
                                boxShadow: factor > 0.05
                                    ? [
                                        BoxShadow(
                                          color: pal.acc.withValues(alpha: 0.28 * factor),
                                          blurRadius: 8 * factor,
                                          offset: Offset(0, 2 * factor),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: tx(
                                      DN[weekdayOf(x)],
                                      size: 10,
                                      color: weekdayColor,
                                      w: factor > 0.5 ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  tx(
                                    '${parseJalaliDate(x)[2]}',
                                    size: 16,
                                    w: FontWeight.bold,
                                    color: numberColor,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    hasItems ? '●' : ' ',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: dotColor,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget dateNavBar(BuildContext c, double currentPage) {
    final T = today();
    final minIdx = currentPage.floor();
    final maxIdx = currentPage.ceil();
    final indices = {minIdx - 1, minIdx, maxIdx, maxIdx + 1};

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: [
          ib(glyph('›'), () => step(-1)),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ClipRect(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final i in indices) ...[
                      () {
                        final offset = i - currentPage;
                        if (offset.abs() > 1.2) return const SizedBox.shrink();

                        final d = pageDate(i);
                        final ws = wStart(d), we = addDays(ws, 6);
                        final away = week ? (T.compareTo(ws) < 0 || T.compareTo(we) > 0) : d != T;
                        final title = week ? '${formatJalaliDate(ws)} تا ${formatJalaliDate(we)}' : '${DN[weekdayOf(d)]} ${formatJalaliDate(d)} ${parseJalaliDate(d)[0]}';
                        final translationX = -offset;
                        final opacity = (1.0 - offset.abs() * 1.1).clamp(0.0, 1.0);

                        return FractionalTranslation(
                          translation: Offset(translationX, 0.0),
                          child: Opacity(
                            opacity: opacity,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                tx(title, w: FontWeight.bold, align: TextAlign.center),
                                const SizedBox(height: 2),
                                if (away)
                                  btn(
                                    'برگرد به امروز',
                                    () => showDate(T),
                                    p: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  )
                                else
                                  tx(week ? 'هفته‌ی جاری' : 'امروز', size: 12, color: pal.mut),
                              ],
                            ),
                          ),
                        );
                      }(),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ib(glyph('‹'), () => step(1)),
        ],
      ),
    );
  }

  Widget weekRow(Item w, String x, VoidCallback go) {
    final t = w.t, n = t.subs.length, cnt = t.subs.where((q) => q.done).length;
    final dn = w.k == 'mdone' || (w.k == 'live' && t.completed), od = w.k == 'live' && !t.completed && x.compareTo(today()) < 0;
    return tap(
      go,
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(width: 46, child: tx(timeOf(t).isEmpty ? '—' : timeOf(t), size: 12, color: od ? pal.red : pal.mut)),
          Expanded(child: tx(t.title, size: 14, color: dn ? pal.mut : null, deco: dn ? TextDecoration.lineThrough : null)),
          if (n > 0) tx('$cnt/$n', size: 12, color: pal.amb),
          const SizedBox(width: 6),
          tx(dn ? '✓' : od ? '⚠️' : isRecurringTask(t) ? '🔁' : '', size: 13),
        ]),
      ),
    );
  }

  Widget weekDay(BuildContext c, String x) {
    final it = itemsOn(x);
    final reminders = app.remindersOn(x);
    void go() => showWeek(false, selected: x);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(16),
        border: x == today() ? Border.all(color: pal.acc, width: 2) : null,
      ),
      child: Column(children: [
        tap(
          go,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                tx('${DN[weekdayOf(x)]} ${formatJalaliDate(x)}', size: 14),
                tx(it.isEmpty && reminders.isEmpty ? '—' : '${it.length} تسک · ${reminders.length} یادآوری', size: 12, color: pal.mut),
              ],
            ),
          ),
        ),
        Container(height: 1, color: pal.bd),
        if (reminders.isNotEmpty) ...[
          secH('یادآوری‌ها', pal.amb, reminders.length),
          for (final r in reminders) reminderCard(c, r),
        ],
        for (final w in it) weekRow(w, x, go),
      ]),
    );
  }

  Widget dayBody(BuildContext c, String d) {
    final T = today(), it = itemsOn(d);
    final reminders = app.remindersOn(d);
    final lv = [for (final x in it) if (x.k == 'live') x.t];
    final mn = [for (final x in it) if (x.k != 'live') x];
    final out = <Widget>[];
    if (reminders.isNotEmpty) {
      out.add(secH('یادآوری‌ها', pal.amb, reminders.length));
      out.addAll(reminders.map((r) => reminderCard(c, r)));
    }
    if (d == T) {
      final ov = app.tasks.where((t) => !t.completed && t.due.compareTo(T) < 0).toList()
        ..sort((a, b) => a.due != b.due ? a.due.compareTo(b.due) : compareTasksByTime(a, b));
      final act = lv.where((t) => !t.completed).toList();
      final pr = act.where((t) => taskStatus(t) == 'prog').toList(), nw = act.where((t) => taskStatus(t) != 'prog').toList();
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
      out.addAll(
        lv.map((t) => taskCard(c, t, cls: t.completed ? 'done' : (t.due.compareTo(T) < 0 ? 'over' : (taskStatus(t) == 'prog' ? 'prog' : '')))),
      );
      out.addAll(mn.map(mini));
    }
    return out.isEmpty ? emptyBox('📭\nبرای این روز موردی نیست.') : Column(children: out);
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: app,
        builder: (c, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Row(
                children: [
                  tx('تقویم', size: 22, w: FontWeight.bold),
                  const SizedBox(width: 14),
                  segBtn('روز', !week, () => showWeek(false)),
                  const SizedBox(width: 6),
                  segBtn('هفته', week, () => showWeek(true)),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _pages,
              builder: (context, _) {
                final p = _currentPage;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: !week
                          ? Padding(
                              padding: const EdgeInsets.only(top: 10, bottom: 4),
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onHorizontalDragEnd: (details) {
                                  if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 150) {
                                    if (details.primaryVelocity! < 0) {
                                      step(1);
                                    } else {
                                      step(-1);
                                    }
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: dayStrip(c, p),
                                ),
                              ),
                            )
                          : const SizedBox(height: 6),
                    ),
                    dateNavBar(c, p),
                  ],
                );
              },
            ),
            const SizedBox(height: 2),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                onPageChanged: (index) => setState(() {
                  _page = index;
                  date = pageDate(index);
                  app.selectedDate = date;
                }),
                itemBuilder: (c, index) {
                  final d = pageDate(index);
                  final ws = wStart(d);
                  return ListView(
                    key: PageStorageKey('cal_content_$d'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                    children: [
                      if (week) ...[
                        for (int i = 0; i < 7; i++) weekDay(c, addDays(ws, i)),
                      ] else ...[
                        dayBody(c, d),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
}
