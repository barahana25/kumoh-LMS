import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 기기에 보관 중인 Canvas 토큰 한 개.
class StoredCanvasToken {
  const StoredCanvasToken({
    required this.token,
    required this.id,
    required this.purpose,
  });

  final String token;
  final int id;
  final String purpose;
}

/// Canvas 설정 화면에서 사용자가 알아볼 수 있는 이름을 만든다.
String buildCanvasTokenPurpose({
  required String platformLabel,
  required String suffix,
}) =>
    '금오LMS 앱 · $platformLabel · $suffix';

String _randomSuffix() {
  const alphabet = '0123456789abcdef';
  final rng = Random.secure();
  return List.generate(4, (_) => alphabet[rng.nextInt(alphabet.length)]).join();
}

abstract interface class CanvasTokenStore {
  Future<StoredCanvasToken?> read();
  Future<void> save(StoredCanvasToken value);

  /// 토큰만 지운다. 기기 이름은 남긴다.
  Future<void> clear();

  /// 이 기기의 토큰 이름. 없으면 만들어 저장한다.
  Future<String> ensurePurpose(String platformLabel);
}

const _kToken = 'canvas_pat_token';
const _kId = 'canvas_pat_id';
const _kPurpose = 'canvas_pat_purpose';

/// 기기 Keychain(iOS) / EncryptedSharedPreferences(Android) 기반 구현.
class SecureCanvasTokenStore implements CanvasTokenStore {
  SecureCanvasTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions:
                  IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<StoredCanvasToken?> read() async {
    final token = await _storage.read(key: _kToken);
    final id = int.tryParse(await _storage.read(key: _kId) ?? '');
    final purpose = await _storage.read(key: _kPurpose);
    if (token == null || token.isEmpty || id == null || purpose == null) {
      return null;
    }
    return StoredCanvasToken(token: token, id: id, purpose: purpose);
  }

  @override
  Future<void> save(StoredCanvasToken value) async {
    await _storage.write(key: _kToken, value: value.token);
    await _storage.write(key: _kId, value: value.id.toString());
    await _storage.write(key: _kPurpose, value: value.purpose);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kId);
  }

  @override
  Future<String> ensurePurpose(String platformLabel) async {
    final existing = await _storage.read(key: _kPurpose);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = buildCanvasTokenPurpose(
      platformLabel: platformLabel,
      suffix: _randomSuffix(),
    );
    await _storage.write(key: _kPurpose, value: created);
    return created;
  }
}

/// 테스트용 구현.
class InMemoryCanvasTokenStore implements CanvasTokenStore {
  StoredCanvasToken? _value;
  String? _purpose;

  @override
  Future<StoredCanvasToken?> read() async => _value;

  @override
  Future<void> save(StoredCanvasToken value) async {
    _value = value;
    _purpose = value.purpose;
  }

  @override
  Future<void> clear() async => _value = null;

  @override
  Future<String> ensurePurpose(String platformLabel) async =>
      _purpose ??= buildCanvasTokenPurpose(
        platformLabel: platformLabel,
        suffix: _randomSuffix(),
      );
}
