import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaidLicense {
  const PaidLicense(this.id, this.customer, this.issuedAt, this.expiresAt);

  final String id;
  final String customer;
  final DateTime issuedAt;
  final DateTime expiresAt;
}

class AppLicense extends ChangeNotifier {
  AppLicense({
    required this.licensed,
    required this.version,
    List<int>? publicKey,
    DateTime Function()? clock,
    Duration Function()? elapsed,
  })  : _publicKey = publicKey,
        _clock = clock ?? DateTime.now {
    _origin = _clock().toUtc();
    _stopwatch.start();
    _elapsed = elapsed ?? (() => _stopwatch.elapsed);
  }

  static final instance = AppLicense(
    licensed: const bool.fromEnvironment('SWIFTMART_LICENSED'),
    version: const String.fromEnvironment(
      'SWIFTMART_VERSION',
      defaultValue: 'development',
    ),
  );
  static const publisher = 'Saravanakumar';
  static const trialDuration = Duration(days: 30);
  static const _clockGrace = Duration(minutes: 5);
  static const _key = 'swiftmart_license_state';

  final bool licensed;
  final String version;
  final DateTime Function() _clock;
  final Stopwatch _stopwatch = Stopwatch();
  List<int>? _publicKey;
  late final Duration Function() _elapsed;
  late final DateTime _origin;
  DateTime? _startedAt;
  DateTime? _lastSeenAt;
  DateTime? _savedAt;
  SharedPreferences? _preferences;
  PaidLicense? _grant;
  String? _code;
  String? _error;
  Future<void>? _initializing;
  Future<void>? _refreshing;
  bool _activating = false;

  DateTime? get expiresAt =>
      _grant?.expiresAt ?? _startedAt?.add(trialDuration);
  String get kind =>
      !licensed ? 'development' : (_grant == null ? 'trial' : 'paid');
  String? get customer => _grant?.customer;
  String? get licenseID => _grant?.id;

  bool get _clockRolledBack {
    final wall = _clock().toUtc();
    return (_lastSeenAt != null &&
            wall.isBefore(_lastSeenAt!.subtract(_clockGrace))) ||
        wall.isBefore(_origin.add(_elapsed()).subtract(_clockGrace));
  }

  DateTime get _highWater {
    final wall = _clock().toUtc();
    final monotonic = _origin.add(_elapsed());
    var result = wall.isAfter(monotonic) ? wall : monotonic;
    if (_lastSeenAt != null && _lastSeenAt!.isAfter(result)) {
      result = _lastSeenAt!;
    }
    return result;
  }

  String? get blockedReason {
    if (!licensed) return null;
    if (_error != null) return _error;
    if (_startedAt == null) return 'License verification is not ready.';
    if (_clockRolledBack) {
      return 'System clock moved backwards. Correct the clock and reopen SwiftMart.';
    }
    if (_grant != null &&
        _grant!.issuedAt.isAfter(_highWater.add(_clockGrace))) {
      return 'This license was issued in the future. Correct the system clock.';
    }
    if (!_highWater.isBefore(expiresAt!)) {
      return 'Your SwiftMart license has expired. Request an extension from Saravanakumar and activate it below.';
    }
    return null;
  }

  bool get active => blockedReason == null;
  int get daysRemaining => !licensed || !active
      ? 0
      : max(
          0,
          (expiresAt!.difference(_highWater).inMicroseconds /
                  Duration.microsecondsPerDay)
              .ceil(),
        );

  void requireActive() {
    final reason = blockedReason;
    if (reason != null) throw StateError(reason);
  }

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    if (!licensed) return;
    try {
      _publicKey ??= base64Decode(
        (await rootBundle.loadString('assets/license-public-key.txt')).trim(),
      );
      if (_publicKey!.length != 32 ||
          !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
        throw StateError('Invalid release metadata or publisher key.');
      }
      _preferences = await SharedPreferences.getInstance();
      final saved = _preferences!.getString(_key);
      if (saved == null) {
        _startedAt = _origin;
        _lastSeenAt = _origin;
        await _save();
      } else {
        final value = jsonDecode(saved);
        if (value is! Map<String, dynamic> ||
            value['version'] != 1 ||
            value['started_at'] is! String ||
            value['last_seen_at'] is! String ||
            (value['license'] != null && value['license'] is! String)) {
          throw const FormatException('Invalid license state.');
        }
        _startedAt = DateTime.parse(value['started_at'] as String).toUtc();
        _lastSeenAt = DateTime.parse(value['last_seen_at'] as String).toUtc();
        if (_lastSeenAt!.isBefore(_startedAt!)) {
          throw const FormatException('Invalid license dates.');
        }
        _code = value['license'] as String?;
        if (_code != null) _grant = await _verify(_code!);
        _savedAt = _lastSeenAt;
      }
      await _refresh();
    } catch (error) {
      _error =
          'Cannot verify this installation. Restore its saved license state or contact Saravanakumar.';
      debugPrint('License initialization failed: ${error.runtimeType}');
    }
    notifyListeners();
  }

  Future<PaidLicense> _verify(String code) async {
    final parts = code.trim().split('.');
    if (code.length > 16384 || parts.length != 3 || parts.first != 'SM1') {
      throw const FormatException('Invalid SwiftMart license format.');
    }
    late final List<int> data;
    late final List<int> signature;
    try {
      data = base64Url.decode(base64Url.normalize(parts[1]));
      signature = base64Url.decode(base64Url.normalize(parts[2]));
    } on FormatException {
      throw const FormatException('Invalid license encoding.');
    }
    if (signature.length != 64 ||
        !await Ed25519().verify(
          data,
          signature: Signature(
            signature,
            publicKey: SimplePublicKey(_publicKey!, type: KeyPairType.ed25519),
          ),
        )) {
      throw const FormatException('License signature is invalid.');
    }
    final value = jsonDecode(utf8.decode(data));
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['product'] != 'SwiftMart' ||
        value['license_id'] is! String ||
        (value['license_id'] as String).trim().isEmpty ||
        value['customer'] is! String ||
        (value['customer'] as String).trim().isEmpty ||
        (value['customer'] as String).length > 200 ||
        value['issued_at'] is! String ||
        value['expires_at'] is! String) {
      throw const FormatException('Invalid license details.');
    }
    final issued = DateTime.parse(value['issued_at'] as String).toUtc();
    final expires = DateTime.parse(value['expires_at'] as String).toUtc();
    if (!expires.isAfter(issued)) {
      throw const FormatException('Invalid license period.');
    }
    return PaidLicense(value['license_id'] as String,
        value['customer'] as String, issued, expires);
  }

  Future<void> activate(String code) async {
    await initialize();
    if (!licensed ||
        _error != null ||
        _preferences == null ||
        _startedAt == null ||
        _lastSeenAt == null ||
        _publicKey == null ||
        _activating) {
      throw StateError('License activation is unavailable or already running.');
    }
    _activating = true;
    try {
      await _refreshing;
      if (_clockRolledBack) {
        throw StateError('Correct the system clock before activation.');
      }
      final next = await _verify(code);
      final now = _highWater;
      if (!next.expiresAt.isAfter(now) ||
          next.issuedAt.isAfter(now.add(_clockGrace))) {
        throw StateError('License is expired or was issued in the future.');
      }
      code = code.trim();
      if (code == _code) return;
      if (!next.expiresAt.isAfter(expiresAt!)) {
        throw StateError(
            'This code does not extend the current expiry. Send the expiry shown here to the publisher.');
      }
      _lastSeenAt = now;
      await _save(code: code);
      _grant = next;
      _code = code;
      _error = null;
      notifyListeners();
    } finally {
      _activating = false;
    }
  }

  Future<void> _save({String? code}) async {
    final value = jsonEncode({
      'version': 1,
      'started_at': _startedAt!.toIso8601String(),
      'last_seen_at': _lastSeenAt!.toIso8601String(),
      if (code != null || _code != null) 'license': code ?? _code,
    });
    if (!await _preferences!.setString(_key, value)) {
      throw StateError('Could not persist license dates.');
    }
    _savedAt = _lastSeenAt;
  }

  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    if (licensed && !_activating && _startedAt != null && _error == null) {
      // Remember the highest observed time; never move it backwards.
      if (!_clockRolledBack) {
        _lastSeenAt = _highWater;
        if (_savedAt == null ||
            _lastSeenAt!.difference(_savedAt!) >= const Duration(minutes: 1) ||
            (!_lastSeenAt!.isBefore(expiresAt!) &&
                _savedAt!.isBefore(expiresAt!))) {
          try {
            await _save();
          } catch (error) {
            _error =
                'Cannot persist license verification. Contact Saravanakumar.';
            debugPrint('License persistence failed: ${error.runtimeType}');
          }
        }
      }
    }
    notifyListeners();
  }
}
