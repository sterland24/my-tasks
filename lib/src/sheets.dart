import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'jalali.dart';
import 'models.dart';
import 'task_logic.dart';
import 'ui_helpers.dart';

// ============================================================
// فرم‌های تسک، تایمر و قالب (با مدیریت چرخه حیات کنترلرها)
// ============================================================
void openTaskForm(BuildContext ctx, {Task? edit}) {
  sheet<void>(ctx, (_) => _TaskFormSheet(edit: edit));
}

void openReminderForm(BuildContext ctx, {Reminder? edit}) {
  sheet<void>(ctx, (_) => _TaskFormSheet(reminderEdit: edit));
}

class _TaskFormSheet extends StatefulWidget {
  final Task? edit;
  final Reminder? reminderEdit;
  const _TaskFormSheet({this.edit, this.reminderEdit});
  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  late String _kind;
  late final Task t;
  late final TextEditingController tc;
  late final TextEditingController nc;
  late final TextEditingController sc;

  @override
  void initState() {
    super.initState();
    _kind = widget.reminderEdit == null ? 'task' : 'reminder';
    final e = widget.edit;
    t = e != null ? e.clone() : Task(id: uid(), title: '');
    if (t.alarm.type == 'none' || t.alarm.type == 'once') {
      t.alarm.date = t.due;
    }
    tc = TextEditingController(text: t.title);
    nc = TextEditingController(text: t.note);
    sc = TextEditingController();
  }

  @override
  void dispose() {
    tc.dispose();
    nc.dispose();
    sc.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final p = t.alarm.time.split(':');
    final r = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])),
    );
    if (r != null) setState(() => t.alarm.time = '${pad(r.hour)}:${pad(r.minute)}');
  }

  void _addSub() {
    final s = sc.text.trim();
    if (s.isEmpty) return;
    setState(() {
      t.subs.add(Sub(uid(), s));
      sc.clear();
    });
  }

  Future<void> _pickTpl() async {
    final id = await sheet<String>(
      context,
      (pc) => sheetBody(pc, [
        sheetHead(pc, 'انتخاب قالب'),
        const SizedBox(height: 4),
        tx(
          'هر تسک فقط یک قالب دارد. با انتخاب قالب دیگر، مراحل قالب قبلی جایگزین می‌شود (مراحلی که خودت اضافه کرده‌ای می‌ماند).',
          size: 12,
          color: pal.mut,
        ),
        const SizedBox(height: 12),
        if (app.tpls.isEmpty) emptyBox('هنوز قالبی نساخته‌ای.\nاز تب «قالب‌ها» یکی بساز.'),
        for (final p in app.tpls)
          tap(
            () => Navigator.pop(pc, p.id),
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pal.card2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.tpl == p.id ? pal.acc : Colors.transparent, width: 2),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    tx(p.name, w: FontWeight.bold),
                    tx('${p.steps.length} مرحله', size: 12, color: pal.mut),
                    for (int i = 0; i < p.steps.length; i++) tx('${i + 1}. ${p.steps[i]}', size: 12, color: pal.mut),
                  ]),
                ),
                Icon(t.tpl == p.id ? Icons.check_circle : Icons.add_circle_outline, color: pal.acc),
              ]),
            ),
          ),
      ]),
    );
    if (id == null) return;
    final p = app.tpls.firstWhere((x) => x.id == id);
    setState(() {
      t.subs.removeWhere((s) => s.tp != null);
      for (final x in p.steps) {
        t.subs.add(Sub(uid(), x, tp: p.id));
      }
      t.tpl = p.id;
    });
  }

  void _save() {
    final a = t.alarm;
    final title = tc.text.trim();
    if (title.isEmpty) return toast('عنوان تسک را وارد کن');
    if (a.type == 'weekly' && a.days.isEmpty) return toast('حداقل یک روز هفته انتخاب کن');
    if (a.type == 'monthly' && a.doms.isEmpty) return toast('حداقل یک روز ماه انتخاب کن');
    t.title = title;
    t.note = nc.text.trim();
    final e = widget.edit;
    if (isRec(t)) {
      t.completed = false;
      t.due = nextOpen(t, today());
    } else {
      t.due = a.date;
      t.completed = t.subs.isNotEmpty ? t.subs.every((s) => s.done) : (e?.completed ?? false);
    }
    if (e != null) {
      final i = app.tasks.indexWhere((x) => x.id == e.id);
      if (i >= 0) app.tasks[i] = t;
    } else {
      app.tasks.insert(0, t);
    }
    app.save(sched: true);
    Navigator.pop(context);
  }

  Widget _timeBox() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        lbl('ساعت'),
        tap(
          _pickTime,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(12)),
            child: tx(t.alarm.time, size: 16, w: FontWeight.bold, color: pal.acc),
          ),
        ),
      ]);

  Widget _dd<V>(V v, List<V> items, void Function(V) f, String Function(V) lab) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<V>(
              value: v,
              isExpanded: true,
              dropdownColor: pal.card2,
              items: [for (final i in items) DropdownMenuItem<V>(value: i, child: tx(lab(i), size: 14))],
              onChanged: (x) {
                if (x != null) f(x);
              },
            ),
          ),
        ),
      );

  Widget _dateRow() {
    final jd = jl(t.alarm.date), jn = jl(today());
    final ys = <int>{jd[0], jn[0], jn[0] + 1, jn[0] + 2}.toList()..sort();
    void setD(int y, int m, int d) => setState(() => t.alarm.date = fromJ(y, m, d));
    return Row(children: [
      _dd<int>(jd[2], List.generate(31, (i) => i + 1), (v) => setD(jd[0], jd[1], v), (v) => '$v'),
      _dd<int>(jd[1], List.generate(12, (i) => i + 1), (v) => setD(jd[0], v, jd[2]), (v) => MN[v - 1]),
      _dd<int>(jd[0], ys, (v) => setD(v, jd[1], jd[2]), (v) => '$v'),
    ]);
  }

  Widget _alarmUi() {
    final a = t.alarm;
    if (a.type == 'none') return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [lbl('تاریخ (شمسی)'), _dateRow()]);
    if (a.type == 'once') return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [lbl('تاریخ (شمسی)'), _dateRow(), _timeBox()]);
    if (a.type == 'daily') return _timeBox();
    if (a.type == 'weekly') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        lbl('روزهای هفته'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final d in DORD)
            chip(DN[d], a.days.contains(d), () => setState(() => a.days.contains(d) ? a.days.remove(d) : a.days.add(d))),
        ]),
        _timeBox(),
      ]);
    }
    if (a.type == 'monthly') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        lbl('هر ماه شمسی در کدام روزها تکرار شود؟ (می‌توانی چند روز انتخاب کنی)'),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (int d = 1; d <= 31; d++)
              tap(
                () => setState(() => a.doms.contains(d) ? a.doms.remove(d) : a.doms.add(d)),
                Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: a.doms.contains(d) ? pal.acc : pal.card2, borderRadius: BorderRadius.circular(10)),
                  child: tx('$d', size: 13, color: a.doms.contains(d) ? Colors.white : pal.mut),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        tx('اگر ماهی آن روز را نداشته باشد (مثلاً ۳۱ مهر)، آخرین روز همان ماه در نظر گرفته می‌شود.', size: 12, color: pal.mut),
        _timeBox(),
      ]);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final a = t.alarm;
    final recOk = (a.type == 'daily') || (a.type == 'weekly' && a.days.isNotEmpty) || (a.type == 'monthly' && a.doms.isNotEmpty);
    String? pv;
    if (recOk) {
      final n = nextOpen(t, today());
      pv = '📅 اولین نوبت: ${DN[wd(n)]} ${jfmt(n)}';
    }

    final taskFields = <Widget>[
      lbl('عنوان تسک *'),
      field(tc, 'عنوان تسک را وارد کن'),
      lbl('یادداشت یا لینک'),
      field(nc, 'اختیاری', lines: 2),
      lbl('مراحل (چک‌لیست)'),
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: (o, n) => setState(() {
          if (n > o) n--;
          final x = t.subs.removeAt(o);
          t.subs.insert(n, x);
        }),
        children: [
          for (int i = 0; i < t.subs.length; i++)
            Container(
              key: ValueKey(t.subs[i].id),
              color: pal.card,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                ReorderableDragStartListener(
                  index: i,
                  child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.drag_handle, color: pal.mut)),
                ),
                Expanded(child: tx(t.subs[i].t)),
                tap(
                  () => setState(() => t.subs.removeAt(i)),
                  Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close, size: 18, color: pal.red)),
                ),
              ]),
            ),
        ],
      ),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: field(sc, 'مرحله جدید…', onSub: (_) => _addSub())),
        const SizedBox(width: 8),
        ib(const Icon(Icons.add, color: Colors.white), _addSub, s: 46),
      ]),
      const SizedBox(height: 10),
      if (t.tpl != null && app.tpls.any((p) => p.id == t.tpl))
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(child: tx('▤ قالب: ${app.tpls.firstWhere((p) => p.id == t.tpl).name}', size: 13)),
            btn('حذف قالب', () => setState(() {
                  t.subs.removeWhere((s) => s.tp != null);
                  t.tpl = null;
                }), fg: pal.red),
          ]),
        ),
      tap(
        _pickTpl,
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(border: Border.all(color: pal.acc), borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: tx(t.tpl != null ? '▤ تغییر قالب' : '▤ انتخاب از قالب آماده', color: pal.acc),
        ),
      ),
      lbl('یادآوری و تکرار'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final x in const [
          ['none', 'بدون آلارم'],
          ['once', 'یک‌بار'],
          ['daily', 'روزانه'],
          ['weekly', 'هفتگی'],
          ['monthly', 'ماهانه'],
        ])
          chip(x[1], a.type == x[0], () => setState(() => a.type = x[0])),
      ]),
      _alarmUi(),
      if (pv != null)
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(10),
          width: double.infinity,
          decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(12)),
          child: tx(pv, size: 13, color: pal.acc),
        ),
      const SizedBox(height: 18),
      btn('ذخیره تسک', _save, bg: pal.acc, fg: Colors.white, wide: true),
    ];

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: sheetBody(context, [
      sheetHead(context, widget.edit != null ? 'ویرایش تسک' : widget.reminderEdit != null ? 'ویرایش یادآوری' : 'افزودن مورد جدید'),
      if (widget.edit == null && widget.reminderEdit == null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final entry in const [('task', 'تسک'), ('reminder', 'یادآوری')])
                tap(
                  () => setState(() => _kind = entry.$1),
                  Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(color: _kind == entry.$1 ? pal.acc : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                    child: tx(entry.$2, size: 12, color: _kind == entry.$1 ? Colors.white : pal.mut, w: _kind == entry.$1 ? FontWeight.bold : null),
                  ),
                ),
            ]),
          ),
        ),
      if (widget.edit != null)
        ...taskFields
      else if (widget.reminderEdit != null)
        _ReminderForm(edit: widget.reminderEdit)
      else ...[
        Visibility(
          visible: _kind == 'task',
          maintainState: true,
          maintainAnimation: true,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: taskFields),
        ),
        Visibility(
          visible: _kind == 'reminder',
          maintainState: true,
          maintainAnimation: true,
          child: const _ReminderForm(),
        ),
      ],
      ]),
    );
  }
}

class _ReminderForm extends StatefulWidget {
  final Reminder? edit;
  const _ReminderForm({this.edit});
  @override
  State<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<_ReminderForm> {
  static const _presetOffsets = {120: '۲ ساعت قبل', 60: '۱ ساعت قبل', 30: '۳۰ دقیقه قبل', 15: '۱۵ دقیقه قبل'};
  late final Reminder r;
  late final TextEditingController tc, nc, customC;

  @override
  void initState() {
    super.initState();
    r = widget.edit?.clone() ?? Reminder(id: uid(), title: '', date: today());
    tc = TextEditingController(text: r.title);
    nc = TextEditingController(text: r.note);
    customC = TextEditingController();
  }

  @override
  void dispose() {
    tc.dispose();
    nc.dispose();
    customC.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final p = r.time.split(':');
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])));
    if (picked != null) setState(() => r.time = '${pad(picked.hour)}:${pad(picked.minute)}');
  }

  void _addCustomOffset() {
    final minutes = int.tryParse(customC.text.trim());
    if (minutes == null) return toast('زمان را به دقیقه وارد کن');
    if (minutes <= 0 || minutes > 43200) return toast('زمان باید بین ۱ تا ۴۳۲۰۰ دقیقه باشد');
    setState(() {
      if (!r.offsets.contains(minutes)) r.offsets.add(minutes);
      r.offsets.sort((a, b) => b.compareTo(a));
      customC.clear();
    });
  }

  Widget _dateRow() {
    final jd = jl(r.date), jn = jl(today());
    final years = <int>{jd[0], jn[0], jn[0] + 1, jn[0] + 2}.toList()..sort();
    void setDate(int y, int m, int d) => setState(() => r.date = fromJ(y, m, d));
    Widget dd(int value, List<int> values, void Function(int) onChanged, String Function(int) label) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: value,
                isExpanded: true,
                dropdownColor: pal.card2,
                items: [for (final v in values) DropdownMenuItem<int>(value: v, child: tx(label(v), size: 14))],
                onChanged: (v) { if (v != null) onChanged(v); },
              ),
            ),
          ),
        );
    return Row(children: [
      dd(jd[2], List.generate(31, (i) => i + 1), (v) => setDate(jd[0], jd[1], v), (v) => '$v'),
      dd(jd[1], List.generate(12, (i) => i + 1), (v) => setDate(jd[0], v, jd[2]), (v) => MN[v - 1]),
      dd(jd[0], years, (v) => setDate(v, jd[1], jd[2]), (v) => '$v'),
    ]);
  }

  void _save() {
    final title = tc.text.trim();
    if (title.isEmpty) return toast('عنوان یادآوری را وارد کن');
    if (widget.edit == null && !atTime(r.date, r.time).isAfter(DateTime.now())) return toast('تاریخ و ساعت یادآوری باید در آینده باشد');
    r.title = title;
    r.note = nc.text.trim();
    app.putReminder(r);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        lbl('عنوان یادآوری *'),
        field(tc, 'عنوان یادآوری را وارد کن'),
        lbl('یادداشت'),
        field(nc, 'اختیاری', lines: 2),
        lbl('تاریخ (شمسی)'),
        _dateRow(),
        lbl('ساعت یادآوری'),
        tap(
          _pickTime,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(12)),
            child: tx(r.time, size: 16, w: FontWeight.bold, color: pal.acc),
          ),
        ),
        lbl('پیش‌یادآوری‌ها'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in _presetOffsets.entries)
            chip(p.value, r.offsets.contains(p.key), () => setState(() {
                  if (r.offsets.contains(p.key)) {
                    r.offsets.remove(p.key);
                  } else {
                    r.offsets.add(p.key);
                  }
                })),
        ]),
        for (final value in (r.offsets.toSet().toList()..sort((a, b) => b.compareTo(a))))
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Expanded(child: tx('${offsetLabel(value)} قبل', size: 13)),
              ib(Icon(Icons.close, size: 16, color: pal.red), () => setState(() => r.offsets.remove(value)), s: 30),
            ]),
          ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: field(customC, 'دقیقه قبل', keyboardType: TextInputType.number, onSub: (_) => _addCustomOffset())),
          const SizedBox(width: 8),
          ib(const Icon(Icons.add, color: Colors.white), _addCustomOffset, s: 46),
        ]),
        const SizedBox(height: 18),
        btn(widget.edit == null ? 'ذخیره یادآوری' : 'ذخیره تغییرات', _save, bg: pal.acc, fg: Colors.white, wide: true),
      ]);
}

void openTimerSheet(BuildContext ctx, Task t) {
  sheet<void>(ctx, (_) => _TimerSheet(task: t));
}

class _TimerSheet extends StatefulWidget {
  final Task task;
  const _TimerSheet({required this.task});
  @override
  State<_TimerSheet> createState() => _TimerSheetState();
}

class _TimerSheetState extends State<_TimerSheet> {
  final TextEditingController cc = TextEditingController(text: '10');
  bool custom = false;

  @override
  void dispose() {
    cc.dispose();
    super.dispose();
  }

  void _go(int m) {
    app.startTimer(widget.task.id, m);
    Navigator.pop(context);
    toast('تایمر $m دقیقه‌ای فعال شد');
  }

  Widget _o(String l, VoidCallback f) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: tap(
            f,
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(14)),
              child: tx(l, w: FontWeight.bold),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return sheetBody(context, [
      sheetHead(context, '⏳ چند دقیقه دیگه یادم بنداز'),
      tx(widget.task.title, size: 13, color: pal.mut),
      const SizedBox(height: 12),
      Row(children: [_o('۱۵ دقیقه دیگه', () => _go(15)), _o('۳۰ دقیقه دیگه', () => _go(30))]),
      Row(children: [_o('۱ ساعت دیگه', () => _go(60)), _o('زمان دلخواه', () => setState(() => custom = true))]),
      if (custom) ...[
        lbl('زمان دلخواه (دقیقه، عدد صحیح از ۱ به بالا)'),
        Row(children: [
          Expanded(
            child: TextField(
              controller: cc,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹]'))],
              style: TextStyle(color: pal.tx, fontFamily: 'Vazirmatn'),
              decoration: deco('دقیقه'),
            ),
          ),
          const SizedBox(width: 8),
          ib(const Icon(Icons.check, color: Colors.white), () {
            final v = int.tryParse(toEn(cc.text));
            if (v == null || v < 1) return toast('یک عدد صحیح، از ۱ دقیقه به بالا وارد کن');
            _go(v);
          }, s: 46),
        ]),
      ],
    ]);
  }
}

void openTplForm(BuildContext ctx, {Tpl? edit}) {
  sheet<void>(ctx, (_) => _TplFormSheet(edit: edit));
}

class _TplFormSheet extends StatefulWidget {
  final Tpl? edit;
  const _TplFormSheet({this.edit});
  @override
  State<_TplFormSheet> createState() => _TplFormSheetState();
}

class _TplFormSheetState extends State<_TplFormSheet> {
  late final TextEditingController nc;
  late final List<TextEditingController> cs;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    nc = TextEditingController(text: e?.name ?? '');
    cs = [for (final s in (e?.steps ?? <String>[''])) TextEditingController(text: s)];
  }

  @override
  void dispose() {
    nc.dispose();
    for (final c in cs) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final e = widget.edit;
    final nm = nc.text.trim();
    final steps = cs.map((c) => c.text.trim()).where((x) => x.isNotEmpty).toList();
    if (nm.isEmpty || steps.isEmpty) return toast('نام و حداقل یک مرحله لازم است');
    if (e != null) {
      e.name = nm;
      e.steps = steps;
    } else {
      app.tpls.add(Tpl(uid(), nm, steps));
    }
    app.save(sched: false);
    Navigator.pop(context);
    toast('قالب ذخیره شد');
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.edit;
    return sheetBody(context, [
      sheetHead(context, e != null ? 'ویرایش قالب' : 'قالب جدید'),
      lbl('نام قالب'),
      field(nc, 'مثلاً: پروسه ویدیو کلاس'),
      lbl('مراحل ثابت (به ترتیب)'),
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: (o, n) => setState(() {
          if (n > o) n--;
          final x = cs.removeAt(o);
          cs.insert(n, x);
        }),
        children: [
          for (int i = 0; i < cs.length; i++)
            Container(
              key: ObjectKey(cs[i]),
              color: pal.card,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                ReorderableDragStartListener(
                  index: i,
                  child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.drag_handle, color: pal.mut)),
                ),
                Expanded(child: field(cs[i], 'مرحله ${i + 1}')),
                tap(
                  () => setState(() {
                    final removed = cs.removeAt(i);
                    removed.dispose();
                  }),
                  Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close, size: 18, color: pal.red)),
                ),
              ]),
            ),
        ],
      ),
      const SizedBox(height: 6),
      tap(
        () => setState(() => cs.add(TextEditingController())),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(border: Border.all(color: pal.acc), borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: tx('+ افزودن مرحله', color: pal.acc),
        ),
      ),
      const SizedBox(height: 16),
      btn('ذخیره قالب', _save, bg: pal.acc, fg: Colors.white, wide: true),
      if (e != null) ...[
        const SizedBox(height: 8),
        btn('حذف قالب', () async {
          if (await confirm(context, 'حذف این قالب؟', e.name)) {
            app.tpls.removeWhere((p) => p.id == e.id);
            app.save(sched: false);
            if (context.mounted) Navigator.pop(context);
            toast('قالب حذف شد');
          }
        }, fg: pal.red, wide: true),
      ],
    ]);
  }
}
