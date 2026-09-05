import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 자동 로그인이 켜졌을 때만 저장되는 학번/비밀번호 한 쌍.
class Credentials {
  const Credentials({required this.userId, required this.password});
  final String userId;
  final String password;
}

/// 토큰·DB 암호화 키·(선택)자격증명 보관소.
/// 구현체는 기기 Keychain/Keystore를 쓰며, 어떤 값도 외부로 전송하지 않는다.
abstract interface class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> saveTokens({required String accessToken, required String refreshToken});
  Future<void> clearTokens();

  /// Drift SQLCipher 키. 없으면 만들어 저장하고, 있으면 그대로 돌려준다.
  Future<String> ensureDbKey();

  Future<void> saveCredentials({required String userId, required String password});
  Future<Credentials?> readCredentials();
  Future<void> clearCredentials();

  /// 토큰 + 자격증명 전부 삭제 (로그아웃).
  Future<void> clearAll();
}

const _kAccess = 'access_token';
const _kRefresh = 'refresh_token';
const _kDbKey = 'db_key';
const _kUserId = 'cred_user_id';
const _kPassword = 'cred_password';

String _generateDbKey() {
  final rng = Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  return base64Url.encode(bytes);
}

/// 기기 Keychain(iOS) / EncryptedSharedPreferences(Android) 기반 구현.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: _kAccess);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
  }

  @override
  Future<void> clearTokens() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }

  @override
  Future<String> ensureDbKey() async {
    final existing = await _storage.read(key: _kDbKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _generateDbKey();
    await _storage.write(key: _kDbKey, value: created);
    return created;
  }

  @override
  Future<void> saveCredentials({required String userId, required String password}) async {
    await _storage.write(key: _kUserId, value: userId);
    await _storage.write(key: _kPassword, value: password);
  }

  @override
  Future<Credentials?> readCredentials() async {
    final id = await _storage.read(key: _kUserId);
    final pw = await _storage.read(key: _kPassword);
    if (id == null || pw == null) return null;
    return Credentials(userId: id, password: pw);
  }

  @override
  Future<void> clearCredentials() async {
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kPassword);
  }

  @override
  Future<void> clearAll() async {
    await clearTokens();
    await clearCredentials();
  }
}

/// 테스트와 위젯 프리뷰에서 쓰는 메모리 구현. DB 키는 유지한다.
class InMemoryTokenStore implements TokenStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> readAccessToken() async => _values[_kAccess];

  @override
  Future<String?> readRefreshToken() async => _values[_kRefresh];

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _values[_kAccess] = accessToken;
    _values[_kRefresh] = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    _values.remove(_kAccess);
    _values.remove(_kRefresh);
  }

  @override
  Future<String> ensureDbKey() async => _values[_kDbKey] ??= _generateDbKey();

  @override
  Future<void> saveCredentials({required String userId, required String password}) async {
    _values[_kUserId] = userId;
    _values[_kPassword] = password;
  }

  @override
  Future<Credentials?> readCredentials() async {
    final id = _values[_kUserId];
    final pw = _values[_kPassword];
    if (id == null || pw == null) return null;
    return Credentials(userId: id, password: pw);
  }

  @override
  Future<void> clearCredentials() async {
    _values.remove(_kUserId);
    _values.remove(_kPassword);
  }

  @override
  Future<void> clearAll() async {
    await clearTokens();
    await clearCredentials();
  }
}
