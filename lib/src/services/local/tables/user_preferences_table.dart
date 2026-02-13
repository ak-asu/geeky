import 'package:drift/drift.dart';

class UserPreferencesEntries extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  TextColumn get fontSize => text().withDefault(const Constant('medium'))();
  BoolColumn get ttsEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get interestsJson => text().withDefault(const Constant('[]'))();
  TextColumn get goalsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
