// Origin 검사는 브라우저가 아닌 클라이언트가 얼마든지 속일 수 있다. 한 곳에서
// 연결을 쌓아 NAS와 학교 서버에 부담을 주지 못하도록 동시 연결 수를 제한한다.
export const MAX_CONNECTIONS_PER_CLIENT = 4;
export const MAX_CONNECTIONS = 200;

export function parseLimit(value, fallback) {
  const n = Number(value);
  return Number.isInteger(n) && n > 0 ? n : fallback;
}

const LOOPBACK = new Set(["127.0.0.1", "::1", "::ffff:127.0.0.1"]);

export function parseFlag(value) {
  return value === "1" || value === "true";
}

// 기본은 같은 호스트의 DSM 리버스 프록시(루프백)를 거친 요청만 X-Forwarded-For를
// 믿는다. 그 밖의 상대가 보낸 X-Forwarded-For는 마음대로 바꿀 수 있어 무시한다.
// Docker 브리지 뒤에서는 프록시가 게이트웨이 주소로 보여 루프백 판정이 안 되므로,
// 포트가 127.0.0.1에만 열려 있을 때에 한해 trustForwardedFor로 항상 믿게 한다.
export function clientAddress(req, { trustForwardedFor = false } = {}) {
  const peer = req.socket.remoteAddress ?? "";
  if (trustForwardedFor || LOOPBACK.has(peer)) {
    const forwarded = req.headers["x-forwarded-for"];
    const first = (Array.isArray(forwarded) ? forwarded[0] : forwarded ?? "")
      .split(",")[0]
      .trim();
    if (first) return first;
  }
  return peer;
}

// 주소는 메모리의 연결 수 집계에만 쓰고 로그에 남기지 않는다.
export function createConnectionLimiter({ perClient, total }) {
  const counts = new Map();
  let active = 0;

  // 자리가 있으면 반납 함수를, 제한을 넘으면 null을 돌려준다.
  return function acquire(address) {
    const current = counts.get(address) ?? 0;
    if (active >= total || current >= perClient) return null;
    counts.set(address, current + 1);
    active++;
    let released = false;
    return () => {
      if (released) return;
      released = true;
      active--;
      const left = counts.get(address) - 1;
      if (left > 0) counts.set(address, left);
      else counts.delete(address);
    };
  };
}
