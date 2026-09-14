/// 웹에서 PWA와 같은 출처(blob:)로 바로 열어도 되는 형식만 남긴다.
///
/// Blob URL은 PWA 출처를 물려받는다. HTML·SVG·XML을 그대로 열면 파일 안의
/// 스크립트가 PWA 저장소의 토큰을 읽을 수 있으므로, 스크립트가 돌 수 없는
/// 형식만 허용하고 나머지는 null(내려받기)로 돌린다.
String? inlineViewableType(String? contentType) {
  if (contentType == null) return null;
  final type = contentType.split(';').first.trim().toLowerCase();
  if (_inlineTypes.contains(type)) return type;
  final slash = type.indexOf('/');
  if (slash <= 0) return null;
  final major = type.substring(0, slash);
  final subtype = type.substring(slash + 1);
  if ((major == 'audio' || major == 'video') && _token.hasMatch(subtype)) {
    return type;
  }
  return null;
}

const _inlineTypes = {
  'application/pdf',
  'image/png',
  'image/jpeg',
  'image/gif',
  'image/webp',
  'text/plain',
};

final _token = RegExp(r'^[a-z0-9][a-z0-9!#$&^_.+-]*$');
