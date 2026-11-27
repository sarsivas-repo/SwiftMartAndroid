import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftmart_frontend/services/api_service.dart';
import 'package:swiftmart_frontend/services/server_settings.dart';
import 'package:swiftmart_frontend/models/models.dart';

void main() {
  test('normalizes supported server addresses', () {
    expect(ServerSettings.normalizeAddress(' https://example.com/ '),
        'https://example.com/api');
    expect(ServerSettings.normalizeAddress('http://192.168.1.5:8080/api/'),
        'http://192.168.1.5:8080/api');
  });

  test('rejects unsafe and ambiguous addresses', () {
    for (final value in [
      'example.com',
      'ftp://example.com',
      'https://user:pass@example.com',
      'https://example.com/shop',
      'https://example.com?token=secret',
      'https://example.com/#fragment',
    ]) {
      expect(
          () => ServerSettings.normalizeAddress(value), throwsFormatException);
    }
  });

  test('persists server and clears the previous session', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = ServerSettings();
    await Future<void>.delayed(Duration.zero);
    ApiService.setAuthToken('previous-session');
    await settings.save('https://example.com');
    expect(settings.address, 'https://example.com/api');
    expect(ApiService.getAuthToken(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('server_address'), 'https://example.com/api');
    settings.dispose();
  });

  test('rejects missing or multiple roles instead of discarding them',
      () async {
    await expectLater(
      ApiService.createUser('test', '', 'password', []),
      throwsArgumentError,
    );
    await expectLater(
      ApiService.createUser(
        'test',
        '',
        'password',
        [UserRole.admin, UserRole.cashier],
      ),
      throwsArgumentError,
    );
  });
}
