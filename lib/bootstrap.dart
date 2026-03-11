import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/services/local/database.dart';

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

  // Firebase — must init before any Firebase service usage
  await Firebase.initializeApp();

  // SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  final db = AppDatabase();

  return (prefs: prefs, db: db);
}
