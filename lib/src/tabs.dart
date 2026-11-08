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
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String pageDate(int index) => addD(_anchor, (index - _firstPage) * (week ? 7 : 1));

  void showDate(String value) {
    final days = pd(value).difference(pd(_anchor)).inDays;
    final target = _firstPage + (week ? days ~/ 7 : days);
    _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void showWeek(bool value, {String? selected}) {
    if (week == value) return;
    _pages.jumpToPage(_page);
    setState(() {
      date = selected ?? date;
      week = value;
      _anchor = addD(date, -(_page - _firstPage) * (week ? 7 : 1));
    });
  }

  String wStart(String d) => addD(d, -((wd(d) + 1) % 7));

  void step(int n) => _pages.animateToPage(
        _page + n,
        duration: const Duration(milliseconds: 300),
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

  Widget stripDay(String x, String selected) {
    final T = today(), on = x == selected;
    final fg = on ? Colors.white : null;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: tap(
          () => showDate(x),
          Container(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
            decoration: BoxDecoration(color: on ? pal.acc : pal.card, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              FittedBox(fit: BoxFit.scaleDown, child: tx(DN[wd(x)], size: 10, color: on ? Colors.white : pal.mut)),
              tx('${jl(x)[2]}', size: 16, w: FontWeight.bold, color: fg ?? (x == T ? pal.acc : pal.tx)),
              Text(itemsOn(x).isNotEmpty || app.remindersOn(x).isNotEmpty ? '●' : ' ', style: TextStyle(fontSize: 8, color: on ? Colors.white : pal.acc)),
            ]),
          ),
        ),
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

  Widget calendarPage(BuildContext c, String d) {
    final T = today(), ws = wStart(d), we = addD(ws, 6);
    final away = week ? (T.compareTo(ws) < 0 || T.compareTo(we) > 0) : d != T;
    final title = week ? '${jfmt(ws)} تا ${jfmt(we)}' : '${DN[wd(d)]} ${jfmt(d)} ${jl(d)[0]}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      children: [
        if (!week)
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [for (int i = 0; i < 7; i++) stripDay(addD(d, i - 3), d)]))
        else
          const SizedBox(height: 12),
        Row(children: [
          ib(glyph('‹'), () => step(-1)),
          Expanded(
            child: Column(children: [
              tx(title, w: FontWeight.bold, align: TextAlign.center),
              if (away)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: btn('برگرد به امروز', () => showDate(T), p: const EdgeInsets.symmetric(horizontal: 12, vertical: 3)),
                )
              else
                tx(week ? 'هفته‌ی جاری' : 'امروز', size: 12, color: pal.mut),
            ]),
          ),
          ib(glyph('›'), () => step(1)),
        ]),
        const SizedBox(height: 4),
        if (week) ...[for (int i = 0; i < 7; i++) weekDay(c, addD(ws, i))] else dayBody(c, d),
      ],
    );
  }

  @override
  Widget build(BuildContext c) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Row(children: [
            tx('تقویم', size: 22, w: FontWeight.bold),
            const SizedBox(width: 14),
            segBtn('روز', !week, () => showWeek(false)),
            const SizedBox(width: 6),
            segBtn('هفته', week, () => showWeek(true)),
          ]),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            onPageChanged: (index) => setState(() {
              _page = index;
              date = pageDate(index);
            }),
            itemBuilder: (c, index) => calendarPage(c, pageDate(index)),
          ),
        ),
      ]);
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
    if (L.isEmpty && completedDays.isEmpty) {
      rows.add((_) => emptyBox('موردی نیست.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
      itemCount: rows.length,
      itemBuilder: (ctx, i) => rows[i](ctx),
    );
  }
}

class TplTab extends StatelessWidget {
  const TplTab({super.key});
  @override
  Widget build(BuildContext c) => ListView(
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          const Spacer(),
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
  Widget build(BuildContext c) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          tx('تنظیمات', size: 22, w: FontWeight.bold),
          const SizedBox(height: 14),
          cardBox(
            child: Row(children: [
              Expanded(child: tx(app.dark ? 'حالت تاریک' : 'حالت روشن', w: FontWeight.bold)),
              Switch(
                key: ValueKey('brightness-${app.dark}'),
                value: app.dark,
                activeColor: pal.acc,
                onChanged: app.setDark,
              ),
            ]),
          ),
          cardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              tx('پوستهٔ برنامه', w: FontWeight.bold),
              const SizedBox(height: 3),
              tx('یکی از چهار سبک را انتخاب کن؛ روشنایی را هم جداگانه می‌توانی تغییر بدهی.', size: 12, color: pal.mut),
              const SizedBox(height: 12),
              SizedBox(
                height: 206,
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.55,
                  children: [
                    _themeTile('classic', 'کلاسیک', 'همان ظاهر آشنای فعلی', pal.acc, pal.card2),
                    _themeTile('glass', 'شیشه‌ای', 'سطوح مات و شفاف', const Color(0xFF46BFAE), const Color(0x777FBCD0)),
                    _themeTile('ocean', 'اقیانوسی', 'سبزآبی و آرام', const Color(0xFF18A998), const Color(0xFF1B5660)),
                    _themeTile('warm', 'گرم', 'رنگ‌های خاکی و نرم', const Color(0xFFB85D34), const Color(0xFF8C6149)),
                  ],
                ),
              ),
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
          final pages = <Widget>[CalTab(key: ValueKey('cal$calReset')), const AllTab(), const TplTab(), const SetTab()];
          const ics = [Icons.calendar_month, Icons.checklist, Icons.view_list, Icons.settings];
          const lbs = ['تقویم', 'همه تسک‌ها', 'قالب‌ها', 'تنظیمات'];
          return Scaffold(
            backgroundColor: pal.bg,
            body: DecoratedBox(decoration: appBackground, child: SafeArea(bottom: false, child: pages[tab])),
            floatingActionButton: tab < 2
                ? FloatingActionButton(
                    onPressed: () => openTaskForm(c),
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
        builder: (c, _) => MaterialApp(
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
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Vazirmatn',
            scaffoldBackgroundColor: pal.bg,
            colorScheme: ColorScheme.fromSeed(seedColor: pal.acc, brightness: app.dark ? Brightness.dark : Brightness.light),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? pal.acc : null),
              trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? pal.acc.withValues(alpha: .35) : null),
            ),
          ),
          home: const HomePage(),
        ),
      );
}
