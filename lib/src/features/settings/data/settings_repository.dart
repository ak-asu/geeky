import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../services/local/database.dart';

class SettingsRepository {
  SettingsRepository(this._api, this._db);

  final ApiService _api;
  final AppDatabase _db;

  /// Requests a GDPR data export from the backend.
  /// The backend queues the export and emails the user a download link.
  Future<void> exportData() async {
    await _api.post(
      '${ApiConstants.users}/me/export',
      {},
      (json) => (json as Map<String, dynamic>?) ?? {},
    );
  }

  /// Permanently deletes the account and all associated data on the backend.
  Future<void> deleteAccount() async {
    await _api.delete('${ApiConstants.users}/me');
  }

  /// Clears all locally cached content for [userId] and the image cache.
  ///
  /// Does not touch user preferences (theme, font size, etc.) or auth state.
  /// Content will re-sync from the backend when next accessed online.
  Future<void> clearOfflineData(String userId) async {
    await _db.deleteAllUserData(userId);
    await DefaultCacheManager().emptyCache();
  }
}
