// 이 중계 서버가 연결을 허용하는 곳. 목록 밖으로는 어떤 바이트도 나가지 않는다.
// 학교 서버와의 TLS는 사용자 브라우저에서 종단하므로 여기서는 암호문만 오간다.
export const ALLOWED_HOSTNAMES = [/^lms\.kumoh\.ac\.kr$/, /^canvas\.kumoh\.ac\.kr$/];
export const ALLOWED_PORTS = [82, 443];

export function applyPolicy(options) {
  options.hostname_whitelist = ALLOWED_HOSTNAMES;
  options.port_whitelist = ALLOWED_PORTS;
  options.allow_direct_ip = false;
  options.allow_private_ips = false;
  options.allow_loopback_ips = false;
  options.allow_udp_streams = false;
  options.stream_limit_total = 16;
  // 리버스 프록시의 X-Forwarded-For를 해석하지 않는다. 로그에 사용자 IP를 남기지 않는다.
  options.parse_real_ip = false;
}

export function parseAllowedOrigins(value) {
  return (value ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

// 다른 사이트가 이 중계 서버를 가져다 쓰는 것을 막는다. 보안 경계는 아니다.
export function isOriginAllowed(origin, allowed) {
  return typeof origin === "string" && allowed.includes(origin);
}
