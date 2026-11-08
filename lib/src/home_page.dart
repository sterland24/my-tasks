import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'all_tasks_tab.dart';
import 'app_state.dart';
import 'calendar_tab.dart';
import 'jalali.dart';
import 'settings_tab.dart';
import 'sheets.dart';
import 'templates_tab.dart';
import 'ui_helpers.dart';

// ============================================================
// صفحه اصلی با حفظ وضعیت تب‌ها (IndexedStack) و اپلیکیشن اصلی
// ============================================================
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
          const ics = [Icons.calendar_month, Icons.checklist, Icons.view_list, Icons.settings];
          const lbs = ['تقویم', 'همه تسک‌ها', 'قالب‌ها', 'تنظیمات'];
          return Scaffold(
            backgroundColor: pal.bg,
            body: DecoratedBox(
              decoration: appBackground,
              child: SafeArea(
                bottom: false,
                child: IndexedStack(
                  index: tab,
                  children: [
                    CalTab(key: ValueKey('cal$calReset')),
                    const AllTab(),
                    const TplTab(),
                    const SetTab(),
                  ],
                ),
              ),
            ),
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
            home: const HomePage(),
          );
        },
      );
}
