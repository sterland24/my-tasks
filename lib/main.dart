import 'package:flutter/material.dart';

import 'src/app_state.dart';
import 'src/tabs.dart';

export 'src/app_state.dart';
export 'src/jalali.dart';
export 'src/models.dart';
export 'src/sheets.dart';
export 'src/tabs.dart';
export 'src/task_logic.dart';
export 'src/ui_helpers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotif();
  await app.load();
  runApp(const MyApp());
}
