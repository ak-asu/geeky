import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'src/core/providers/database_provider.dart';
import 'src/core/providers/shared_preferences_provider.dart';

void main() async {
  final result = await bootstrap();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(result.prefs),
        appDatabaseProvider.overrideWithValue(result.db),
      ],
      child: const GeekyApp(),
    ),
  );
}
