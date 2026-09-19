import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/existence_record.dart';

enum WatchdogSyncResult { synced, notPaired, unavailable }

class WatchdogService {
  WatchdogService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 8);

  Future<WatchdogSyncResult> syncCheckIn({
    required String subjectId,
    required DateTime checkedInAt,
  }) async {
    try {
      final tokenResponse = await _client
          .get(Uri.parse(BackendConfig.authTokenUrl))
          .timeout(_timeout);
      if (tokenResponse.statusCode != 200) {
        return WatchdogSyncResult.unavailable;
      }
      final decoded = jsonDecode(tokenResponse.body);
      if (decoded is! Map || decoded['token'] is! String) {
        return WatchdogSyncResult.unavailable;
      }

      final response = await _client
          .post(
            Uri.parse('${BackendConfig.dataApiUrl}/rpc/refresh_watchdog'),
            headers: <String, String>{
              'Authorization': 'Bearer ${decoded['token']}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object>{
              'p_subject_id': subjectId,
              'p_checked_in_at': checkedInAt.toUtc().toIso8601String(),
              'p_deadline_at': checkedInAt
                  .add(ExistenceRecord.filingWindow)
                  .toUtc()
                  .toIso8601String(),
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return WatchdogSyncResult.unavailable;
      }
      final result = jsonDecode(response.body);
      if (result == true) return WatchdogSyncResult.synced;
      if (result == false) return WatchdogSyncResult.notPaired;
      return WatchdogSyncResult.unavailable;
    } catch (_) {
      return WatchdogSyncResult.unavailable;
    }
  }
}
