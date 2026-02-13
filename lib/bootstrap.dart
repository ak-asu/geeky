import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/services/local/database.dart';
import 'src/services/mock_data_service.dart';

/// Bootstrap result containing initialized services.
typedef BootstrapResult = ({SharedPreferences prefs, AppDatabase db});

/// Initializes all services before app launch.
Future<BootstrapResult> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // System UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Ensure Drift DB is ready
  final db = AppDatabase();
  await db.customSelect('SELECT 1').get();

  // Seed mock data on first launch
  await MockDataService(db, prefs).seedIfNeeded();

  return (prefs: prefs, db: db);
}
