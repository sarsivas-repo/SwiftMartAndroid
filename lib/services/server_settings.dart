import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'local_database.dart';
import 'local_users.dart';

class ServerSettings extends ChangeNotifier {
  static const _addressKey = 'server_address';
  static const localAddress = 'local://standalone';

  bool loading = true;
  String? address;
  String? error;
  LocalUsers? localUsers;

  ServerSettings() {
    _load();
  }

  static String normalizeAddress(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty &&
            uri.path != '/' &&
            uri.path != '/api' &&
            uri.path != '/api/')) {
      throw const FormatException(
          'Enter an HTTP or HTTPS server address without credentials or a path.');
    }
    return uri.replace(path: '/api', query: null, fragment: null).toString();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_addressKey);
      if (saved != null) {
        if (saved == localAddress) {
          localUsers = await LocalDatabase.open();
          ApiService.configureLocal(localUsers!);
          address = saved;
        } else {
          address = normalizeAddress(saved);
          ApiService.configureServer(address!);
        }
      }
    } catch (exception) {
      error = 'Unable to load saved server address: $exception';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> save(String value) async {
    final normalized = normalizeAddress(value);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_addressKey, normalized)) {
      throw StateError('Could not save server address.');
    }
    ApiService.configureServer(normalized);
    localUsers = null;
    address = normalized;
    error = null;
    notifyListeners();
  }

  Future<void> useLocal() async {
    final users = await LocalDatabase.open();
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_addressKey, localAddress)) {
      throw StateError('Could not save standalone mode.');
    }
    ApiService.configureLocal(users);
    localUsers = users;
    address = localAddress;
    error = null;
    notifyListeners();
  }

  void edit() {
    address = null;
    error = null;
    notifyListeners();
  }
}
