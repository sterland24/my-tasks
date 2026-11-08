import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'jalali.dart';
import 'models.dart';
import 'sheets.dart';
import 'task_logic.dart';
import 'ui_helpers.dart';

// ============================================================
// تب تقویم، همه تسک‌ها، قالب‌ها، تنظیمات و صفحه اصلی
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

  String pageDate(int index) => addD(_anchor, (index - _firstPage) * (week ? 7 : 1));

  double get _currentPage =>
      _pages.hasClients && _pages.position.haveDimensions
          ? (_pages.page ?? _page.toDouble())
          : _page.toDouble();

  void showDate(String value) {
    final days = pd(value).difference(pd(_anchor)).inDays;
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
      _anchor = addD(date, -(_page - _firstPage) * (week ? 7 : 1));
    });
  }

  String wStart(String d) => addD(d, -((wd(d) + 1) % 7));

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
                                      DN[wd(x)],
                                      size: 10,
                                      color: weekdayColor,
                                      w: factor > 0.5 ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  tx(
                                    '${jl(x)[2]}',
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
                        final ws = wStart(d), we = addD(ws, 6);
                        final away = week ? (T.compareTo(ws) < 0 || T.compareTo(we) > 0) : d != T;
                        final title = week ? '${jfmt(ws)} تا ${jfmt(we)}' : '${DN[wd(d)]} ${jfmt(d)} ${jl(d)[0]}';
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
          SizedBox(width: 46, child: tx(tmOf(t).isEmpty ? '—' : tmOf(t), size: 12, color: od ? pal.red : pal.mut)),
          Expanded(child: tx(t.title, size: 14, color: dn ? pal.mut : null, deco: dn ? TextDecoration.lineThrough : null)),
          if (n > 0) tx('$cnt/$n', size: 12, color: pal.amb),
          const SizedBox(width: 6),
          tx(dn ? '✓' : od ? '⚠️' : isRec(t) ? '🔁' : '', size: 13),
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
                tx('${DN[wd(x)]} ${jfmt(x)}', size: 14),
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
        ..sort((a, b) => a.due != b.due ? a.due.compareTo(b.due) : byTime(a, b));
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
      out.addAll(
        lv.map((t) => taskCard(c, t, cls: t.completed ? 'done' : (t.due.compareTo(T) < 0 ? 'over' : (st(t) == 'prog' ? 'prog' : '')))),
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
                        for (int i = 0; i < 7; i++) weekDay(c, addD(ws, i)),
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
          Widget fr(BuildContext ctx, Task t) =>
              taskCard(ctx, t, cls: t.completed ? 'done' : (t.due.compareTo(T) < 0 ? 'over' : (st(t) == 'prog' ? 'prog' : '')));
          String dl(String k) => '${k == T ? 'امروز · ' : ''}${DN[wd(k)]} ${jfmt(k)}${jl(k)[0] != jl(T)[0] ? ' ${jl(k)[0]}' : ''}';
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

class TplTab extends StatelessWidget {
  const TplTab({super.key});
  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: app,
        builder: (c, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
          children: [
            tx('قالب‌ها', size: 22, w: FontWeight.bold),
            tx('مراحل ثابت کارهای تکراری را یک‌بار بساز و هر جا خواستی استفاده کن.', size: 13, color: pal.mut),
            const SizedBox(height: 14),
            for (final p in app.tpls)
              tap(
                () => openTplForm(c, edit: p),
                cardBox(
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [tx(p.name, w: FontWeight.bold), tx(p.steps.join(' ← '), size: 12, color: pal.mut)],
                      ),
                    ),
                    Icon(Icons.edit, size: 18, color: pal.mut),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            btn('+ قالب جدید', () => openTplForm(c), bg: pal.acc, fg: Colors.white, wide: true),
          ],
        ),
      );
}

class SetTab extends StatelessWidget {
  const SetTab({super.key});

  Widget _themeTile(String id, String title, String detail, Color accent, Color surface) {
    final selected = app.themeId == id;
    return tap(
      () => app.setTheme(id),
      Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected ? pal.card2 : pal.card,
          borderRadius: BorderRadius.circular(pal.radius),
          border: Border.all(color: selected ? accent : pal.bd, width: selected ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(10)),
              child: Icon(selected ? Icons.check : Icons.palette_outlined, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(child: tx(title, size: 13, w: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          tx(detail, size: 10, color: pal.mut, maxLines: 1),
          const SizedBox(height: 7),
          Row(children: [
            for (final color in [surface, accent, pal.bd])
              Expanded(
                child: Container(
                  height: 8,
                  margin: const EdgeInsetsDirectional.only(end: 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: app,
        builder: (c, _) {
          final classicPal = app.dark ? darkPal : lightPal;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
            children: [
              tx('تنظیمات', size: 22, w: FontWeight.bold),
              const SizedBox(height: 14),
              cardBox(
                child: tap(
                  () => app.setDark(!app.dark),
                  Row(children: [
                    Expanded(child: tx(app.dark ? 'حالت تاریک' : 'حالت روشن', w: FontWeight.bold)),
                    Switch(
                      value: app.dark,
                      activeColor: pal.acc,
                      onChanged: app.setDark,
                    ),
                  ]),
                ),
              ),
              cardBox(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  tx('پوستهٔ برنامه', w: FontWeight.bold),
                  const SizedBox(height: 3),
                  tx('یکی از چهار سبک را انتخاب کن؛ روشنایی را هم جداگانه می‌توانی تغییر بدهی.', size: 12, color: pal.mut),
                  const SizedBox(height: 12),
                  Column(children: [
                    Row(children: [
                      Expanded(child: _themeTile('classic', 'کلاسیک', 'همان ظاهر آشنای فعلی', classicPal.acc, classicPal.card2)),
                      const SizedBox(width: 8),
                      Expanded(child: _themeTile('glass', 'شیشه‌ای', 'سطوح مات و شفاف', const Color(0xFF46BFAE), const Color(0x777FBCD0))),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _themeTile('ocean', 'اقیانوسی', 'سبزآبی و آرام', const Color(0xFF18A998), const Color(0xFF1B5660))),
                      const SizedBox(width: 8),
                      Expanded(child: _themeTile('warm', 'گرم', 'رنگ‌های خاکی و نرم', const Color(0xFFB85D34), const Color(0xFF8C6149))),
                    ]),
                  ]),
                ]),
              ),
              cardBox(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  tx('پشتیبان‌گیری و بازگردانی', w: FontWeight.bold),
                  const SizedBox(height: 4),
                  tx('فایل JSON می‌سازد و با «اشتراک‌گذاری» می‌توانی آن را در فایل‌های گوشی، تلگرام یا Drive ذخیره کنی.', size: 12, color: pal.mut),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [btn('⬇ ساخت فایل پشتیبان', exportBackup), btn('⬆ بازگردانی از فایل', () => importBackup(c))],
                  ),
                ]),
              ),
              cardBox(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  tx('یادآوری‌ها', w: FontWeight.bold),
                  const SizedBox(height: 4),
                  tx(
                    'اگر یادآورها با تأخیر آمدند، در تنظیمات گوشی «بهینه‌سازی باتری» را برای این برنامه روی «بدون محدودیت» بگذار.',
                    size: 12,
                    color: pal.mut,
                  ),
                ]),
              ),
              cardBox(
                child: btn('حذف همه اطلاعات', () async {
                  if (await confirm(c, 'حذف همه اطلاعات؟', 'همه تسک‌ها و قالب‌ها')) {
                    app.seed();
                    app.save(sched: true);
                    toast('همه اطلاعات پاک شد');
                  }
                }, fg: pal.red),
              ),
            ],
          );
        },
      );
}

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
            body: DecoratedBox(decoration: appBackground, child: SafeArea(bottom: false, child: pages[tab])),
            floatingActionButton: tab < 2
                ? FloatingActionButton(
                    onPressed: () {
                      final initD = tab == 0 && app.selectedDate.compareTo(today()) >= 0 ? app.selectedDate : today();
                      openTaskForm(c, initialDate: initD);
                    },
                    backgroundColor: pal.acc,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(pal.radius)),
                    child: const Icon(Icons.add, size: 30),
                  )
                : null,
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
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(ics[i], color: tab == i ? pal.acc : pal.mut),
                              tx(lbs[i], size: 11, color: tab == i ? pal.acc : pal.mut),
                            ],
                          ),
                        ),
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
        builder: (c, _) {
          final p = pal;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: msgKey,
            title: 'وظایف من',
            locale: const Locale('fa'),
            supportedLocales: const [Locale('fa')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeAnimationDuration: Duration.zero,
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'Vazirmatn',
              scaffoldBackgroundColor: p.bg,
              colorScheme: ColorScheme.fromSeed(seedColor: p.acc, brightness: app.dark ? Brightness.dark : Brightness.light),
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? p.acc : null),
                trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? p.acc.withValues(alpha: .35) : null),
              ),
            ),
            home: HomePage(),
          );
        },
      );
}
