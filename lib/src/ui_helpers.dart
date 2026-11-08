import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'jalali.dart';
import 'models.dart';
import 'sheets.dart';
import 'task_logic.dart';

// ============================================================
// ظاهر: رنگ‌ها، ابزارهای کوچک و کارت تسک
// ============================================================
class Pal {
  final Color bg, card, card2, tx, mut, acc, amb, red, grn, bd;
  const Pal(this.bg, this.card, this.card2, this.tx, this.mut, this.acc, this.amb, this.red, this.grn, this.bd);
}

const darkPal = Pal(
  Color(0xFF12161F),
  Color(0xFF1A2030),
  Color(0xFF222A3D),
  Color(0xFFEEF1F8),
  Color(0xFF8D97AE),
  Color(0xFF8B9CFF),
  Color(0xFFFFB547),
  Color(0xFFFF6B6B),
  Color(0xFF4CD29A),
  Color(0xFF2C3550),
);
const lightPal = Pal(
  Color(0xFFF3F5FA),
  Color(0xFFFFFFFF),
  Color(0xFFEAEEF7),
  Color(0xFF1B2233),
  Color(0xFF67718A),
  Color(0xFF4F5FE0),
  Color(0xFFD98300),
  Color(0xFFD93A3A),
  Color(0xFF17996A),
  Color(0xFFD9DEEC),
);
Pal get pal => app.dark ? darkPal : lightPal;

Widget tx(
  String s, {
  double size = 15,
  Color? color,
  FontWeight? w,
  TextAlign? align,
  int? maxLines,
  TextDecoration? deco,
  TextDirection? dir,
}) =>
    Text(
      fa(s),
      textAlign: align,
      maxLines: maxLines,
      textDirection: dir,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      style: TextStyle(fontSize: size, color: color ?? pal.tx, fontWeight: w, decoration: deco, height: 1.5),
    );

Widget tap(VoidCallback f, Widget c) => GestureDetector(behavior: HitTestBehavior.opaque, onTap: f, child: c);

Widget ib(Widget child, VoidCallback f, {double s = 36}) => tap(
      f,
      Container(
        width: s,
        height: s,
        decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: child,
      ),
    );

Widget glyph(String g) => Text(g, style: TextStyle(fontSize: 22, color: pal.tx, height: 1.1));

Widget chk(bool on, VoidCallback f, {double s = 26}) => tap(
      f,
      Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: on ? pal.grn : null,
          border: Border.all(color: on ? pal.grn : pal.mut, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: on ? Icon(Icons.check, size: s - 10, color: Colors.white) : null,
      ),
    );

Widget btn(
  String l,
  VoidCallback f, {
  Color? bg,
  Color? fg,
  bool wide = false,
  EdgeInsets p = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
}) =>
    tap(
      f,
      Container(
        width: wide ? double.infinity : null,
        padding: wide ? const EdgeInsets.symmetric(vertical: 13) : p,
        decoration: BoxDecoration(color: bg ?? pal.card2, borderRadius: BorderRadius.circular(wide ? 14 : 10)),
        alignment: wide ? Alignment.center : null,
        child: tx(l, size: wide ? 15 : 13, color: fg, w: wide ? FontWeight.bold : null),
      ),
    );

Widget chip(String l, bool on, VoidCallback f) => tap(
      f,
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(color: on ? pal.acc : pal.card2, borderRadius: BorderRadius.circular(20)),
        child: tx(l, size: 13, color: on ? Colors.white : pal.mut),
      ),
    );

Widget cardBox({required Widget child, Color? stripe, Color? bg, double op = 1}) => Opacity(
      opacity: op,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: bg ?? pal.card,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(start: BorderSide(color: stripe ?? pal.bd, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
            child: child,
          ),
        ),
      ),
    );

Widget secH(String ti, Color col, int n) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        tx('$ti ($n)', size: 14, w: FontWeight.bold),
      ]),
    );

Widget emptyBox(String m) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 10),
      child: Center(child: tx(m, color: pal.mut, align: TextAlign.center)),
    );

Widget lbl(String s) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: tx(s, size: 13, color: pal.mut));

InputDecoration deco(String hint) {
  OutlineInputBorder b(Color c) => OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c));
  return InputDecoration(
    hintText: fa(hint),
    hintStyle: TextStyle(color: pal.mut),
    filled: true,
    fillColor: pal.card2,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: b(pal.bd),
    enabledBorder: b(pal.bd),
    focusedBorder: b(pal.acc),
  );
}

Widget field(TextEditingController c, String hint, {int lines = 1, ValueChanged<String>? onSub, TextInputType? keyboardType}) => TextField(
      controller: c,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 5,
      onSubmitted: onSub,
      keyboardType: keyboardType,
      style: TextStyle(color: pal.tx, fontFamily: 'Vazirmatn'),
      decoration: deco(hint),
    );

void toast(String m) {
  final s = msgKey.currentState;
  if (s == null) return;
  s.hideCurrentSnackBar();
  s.showSnackBar(
    SnackBar(
      content: Text(fa(m), style: TextStyle(color: pal.bg, fontFamily: 'Vazirmatn')),
      backgroundColor: pal.tx,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2200),
    ),
  );
}

Future<bool> confirm(BuildContext c, String title, String sub) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (dc) => AlertDialog(
      backgroundColor: pal.card,
      title: tx(title, w: FontWeight.bold),
      content: tx('«$sub»\nاین کار قابل بازگشت نیست.', color: pal.mut),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc, false), child: tx('انصراف', color: pal.mut)),
        TextButton(onPressed: () => Navigator.pop(dc, true), child: tx('بله، حذف شود', color: pal.red)),
      ],
    ),
  );
  return r == true;
}

Future<T?> sheet<T>(BuildContext c, WidgetBuilder b) => showModalBottomSheet<T>(
      context: c,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: pal.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: b,
    );

Widget sheetBody(BuildContext c, List<Widget> children) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );

Widget sheetHead(BuildContext c, String t) => Row(children: [
      Expanded(child: tx(t, size: 17, w: FontWeight.bold)),
      ib(Icon(Icons.close, size: 18, color: pal.tx), () => Navigator.pop(c)),
    ]);

String fmtCd(int ms) {
  final s = (ms / 1000).ceil();
  return '${pad(s ~/ 60)}:${pad(s % 60)}';
}

Widget taskCard(BuildContext c, Task t, {String cls = ''}) {
  final n = t.subs.length, cnt = t.subs.where((s) => s.done).length, s = st(t);
  final ex = app.ex.contains(t.id), od = !t.completed && t.due.compareTo(today()) < 0, lt = late(t);
  final al = t.alarm.type == 'once' ? '🔔 ساعت ${t.alarm.time}' : alarmTxt(t.alarm);
  final due = t.due == today() ? 'امروز' : jfmt(t.due);
  final stripe = (cls == 'over' || lt) ? pal.red : cls == 'prog' ? pal.amb : cls == 'done' ? pal.grn : pal.bd;
  return cardBox(
    stripe: stripe,
    bg: lt ? Color.alphaBlend(pal.red.withValues(alpha: .12), pal.card) : null,
    op: s == 'done' ? .6 : 1,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (n == 0) ...[chk(s == 'done', () => app.toggleChk(t)), const SizedBox(width: 10)],
        Expanded(
          child: tap(
            () => app.toggleEx(t.id),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              tx(t.title, w: FontWeight.bold),
              const SizedBox(height: 2),
              Wrap(spacing: 10, children: [
                tx(od ? 'عقب‌افتاده از $due' : jfmt(t.due), size: 12, color: od ? pal.red : pal.mut),
                if (al.isNotEmpty) tx(al, size: 12, color: lt ? pal.red : pal.mut),
              ]),
            ]),
          ),
        ),
        if (s != 'done') ib(const Text('⏳', style: TextStyle(fontSize: 17)), () => openTimerSheet(c, t)),
      ]),
      if (n > 0) ...[
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: cnt / n,
            minHeight: 6,
            backgroundColor: pal.card2,
            valueColor: AlwaysStoppedAnimation(pal.amb),
          ),
        ),
        const SizedBox(height: 5),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          tx('$cnt از $n مرحله', size: 12, color: pal.mut),
          tx(s == 'prog' ? 'در حال انجام' : s == 'done' ? 'تکمیل' : 'شروع نشده', size: 12, color: pal.mut),
        ]),
      ],
      ListenableBuilder(
        listenable: app.timerTick,
        builder: (c, _) {
          final left = app.timerLeft(t.id);
          if (left <= 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: tap(
              () => app.cancelTimer(t.id),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(20)),
                child: tx('⏳ ${fmtCd(left)} · لغو', size: 12, color: pal.acc),
              ),
            ),
          );
        },
      ),
      if (ex)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.bd))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (t.note.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                decoration: BoxDecoration(color: pal.card2, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Expanded(
                    child: tx(
                      t.note,
                      size: 13,
                      dir: RegExp(r'[\u0600-\u06FF]').hasMatch(t.note) ? TextDirection.rtl : TextDirection.ltr,
                    ),
                  ),
                  ib(Icon(Icons.copy, size: 16, color: pal.tx), () {
                    Clipboard.setData(ClipboardData(text: t.note));
                    toast('کپی شد');
                  }, s: 32),
                ]),
              ),
            for (final x in t.subs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  chk(x.done, () => app.toggleSub(t, x), s: 22),
                  const SizedBox(width: 10),
                  Expanded(child: tx(x.t, color: x.done ? pal.mut : null, deco: x.done ? TextDecoration.lineThrough : null)),
                ]),
              ),
            const SizedBox(height: 8),
            Row(children: [
              if (isRec(t)) ...[
                btn('↷ رد کردن این نوبت', () => app.skipOcc(t, t.due), fg: pal.amb),
                const SizedBox(width: 8),
              ],
              btn('✎ ویرایش', () => openTaskForm(c, edit: t)),
              const SizedBox(width: 8),
              btn('حذف', () async {
                if (await confirm(c, 'حذف این تسک؟', t.title)) app.deleteTask(t.id);
              }, fg: pal.red),
            ]),
          ]),
        ),
    ]),
  );
}

Widget mini(Item x) {
  final t = x.t, pl = x.k == 'plan', ok = !pl && x.d.compareTo(today()) >= 0;
  final al = alarmTxt(t.alarm);
  return cardBox(
    op: pl ? 1 : .6,
    child: Row(children: [
      ok
          ? chk(true, () => app.toggleOcc(t, x.d))
          : Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: pl ? pal.mut : pal.grn, shape: BoxShape.circle),
            ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          tx(t.title, w: FontWeight.bold),
          Wrap(spacing: 10, children: [
            tx(jfmt(x.d), size: 12, color: pal.mut),
            if (al.isNotEmpty) tx(al, size: 12, color: pal.mut),
            tx(pl ? 'برنامه‌ریزی‌شده' : 'انجام شد ✓', size: 12, color: pal.mut),
          ]),
        ]),
      ),
      if (pl && isRec(t))
        btn('رد کردن', () => app.skipOcc(t, x.d), fg: pal.amb, p: const EdgeInsets.symmetric(horizontal: 9, vertical: 6)),
    ]),
  );
}

String offsetLabel(int minutes) {
  if (minutes >= 60 && minutes % 60 == 0) return '${minutes ~/ 60} ساعت';
  if (minutes > 60) return '${minutes ~/ 60} ساعت و ${minutes % 60} دقیقه';
  return '$minutes دقیقه';
}

Widget reminderCard(BuildContext c, Reminder r) => cardBox(
      stripe: pal.amb,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          chk(false, () => app.completeReminder(r.id)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              tx(r.title, w: FontWeight.bold),
              tx('${jfmt(r.date)} · ${r.time}', size: 12, color: pal.amb),
            ]),
          ),
          ib(Icon(Icons.edit, size: 17, color: pal.mut), () => openReminderForm(c, edit: r), s: 34),
          const SizedBox(width: 6),
          ib(Icon(Icons.delete_outline, size: 18, color: pal.red), () async {
            if (await confirm(c, 'حذف یادآوری؟', r.title)) app.deleteReminder(r.id);
          }, s: 34),
        ]),
        if (r.note.isNotEmpty)
          Padding(padding: const EdgeInsetsDirectional.only(start: 38, top: 6), child: tx(r.note, size: 13, color: pal.mut)),
        if (r.offsets.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 38, top: 4),
            child: tx('پیش‌یادآوری: ${r.offsets.map(offsetLabel).join('، ')} قبل', size: 11, color: pal.mut),
          ),
      ]),
    );
