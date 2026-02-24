import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';

class SettingsRepository {
  SettingsRepository(this._api);

  final ApiService _api;

  /// Requests a GDPR data export from the backend.
  /// Returns the exported data as a raw map.
  Future<Map<String, dynamic>> exportData() async {
    final result = await _api.post(
      '${ApiConstants.users}/me/export',
      {},
      (json) => (json as Map<String, dynamic>?) ?? {},
    );
    return result;
  }

  /// Permanently deletes the account and all associated data on the backend.
  Future<void> deleteAccount() async {
    await _api.delete('${ApiConstants.users}/me');
  }
}
