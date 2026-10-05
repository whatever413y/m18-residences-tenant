import 'package:shared_preferences/shared_preferences.dart';

/// The account ID "Remember me" keeps in this browser's storage, to prefill the login next time.
/// It stays on the device: nothing is sent anywhere.
class RememberedAccount {
  static const _key = 'remembered_account_id';

  static Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);

  static Future<void> save(String accountId) async {
    if (!await (await SharedPreferences.getInstance()).setString(_key, accountId)) {
      throw StateError('Could not save the account ID in this browser');
    }
  }

  static Future<void> forget() async => (await SharedPreferences.getInstance()).remove(_key);
}
