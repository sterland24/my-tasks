import 'package:flutter/material.dart';

import 'app_state.dart';
import 'sheets.dart';
import 'ui_helpers.dart';

// ============================================================
// تب قالب‌ها (مدیریت مراحل ثابت کارهای تکراری)
// ============================================================
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
