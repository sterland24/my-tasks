import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui_helpers.dart';

// ============================================================
// تب تنظیمات (تغییر تم، حالت تاریک/روشن، پشتیبان‌گیری)
// ============================================================
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
