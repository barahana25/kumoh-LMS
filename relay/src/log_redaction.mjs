// wisp-js는 연결 로그에 접속자의 IP 주소를 그대로 남긴다(src/server/http.mjs의
// "new connection on ... from ${real_ip}"). wisp-js는 ES 모듈이라 밖에서
// logging.info 등을 재할당할 수 없으므로, console 쪽을 가로채 IP만 지운다.

// IPv4: 1-3자리 옥텟 4개를 점으로 구분. 호스트명(lms.kumoh.ac.kr:82) 뒤 포트 숫자나
// 타임스탬프([2026/09/14 - 12:34:56])의 숫자와 겹치지 않도록 단어 경계로 감싼다.
const IPV4_RE = /\b(?:\d{1,3}\.){3}\d{1,3}\b/g;

// IPv6: ::1, ::ffff:203.0.113.7(IPv4-매핑), 2001:db8::1, 전체 8묶음 표기까지 잡는다.
// "lms.kumoh.ac.kr:82"(호스트명:포트, 콜론 1개)나 "12:34:56"(타임스탬프, 콜론 2개지만 "::" 압축이 없음)과
// 겹치지 않도록 압축 표기("::")가 있거나 콜론 7개짜리 완전 표기일 때만 매칭한다.
const H = "[0-9a-fA-F]{1,4}";
const IPV4_IN_V6 = "(?:(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)\\.){3}(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)";
const IPV6_RE = new RegExp(
  "(?<![0-9a-fA-F:.])(?:" +
    `(?:${H}:){7}${H}` + "|" + // 1:2:3:4:5:6:7:8 (완전 표기)
    `(?:${H}:){1,7}:` + "|" + // 1::   1:2:3:4:5:6:7::
    `(?:${H}:){1,6}:${H}` + "|" + // 1::8   1:2:3:4:5:6::8
    `(?:${H}:){1,5}(?::${H}){1,2}` + "|" +
    `(?:${H}:){1,4}(?::${H}){1,3}` + "|" +
    `(?:${H}:){1,3}(?::${H}){1,4}` + "|" +
    `(?:${H}:){1,2}(?::${H}){1,5}` + "|" +
    `${H}:(?:(?::${H}){1,6})` + "|" +
    `:(?:(?::${H}){1,7}|:)` + "|" + // ::2:3:4:5:6:7:8   ::8   ::
    `(?:${H}:){1,4}:${IPV4_IN_V6}` + "|" + // 2001:db8::192.0.2.33 (IPv4 내장)
    `::(?:ffff(?::0{1,4})?:)?${IPV4_IN_V6}` + // ::ffff:203.0.113.7 (IPv4-매핑)
    ")(?![0-9a-fA-F:.])",
  "g",
);

export function redactLogText(text) {
  return text.replace(IPV6_RE, "[ip]").replace(IPV4_RE, "[ip]");
}

const installed = new WeakSet();

export function installLogRedaction(target = console) {
  if (installed.has(target)) return target;
  installed.add(target);

  for (const method of ["debug", "info", "log", "warn", "error"]) {
    const original = target[method].bind(target);
    target[method] = (...args) => {
      const redacted = args.map((a) => (typeof a === "string" ? redactLogText(a) : a));
      return original(...redacted);
    };
  }

  return target;
}
