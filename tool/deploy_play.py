"""빌드한 앱 번들을 Google Play에 올리고 지정한 트랙에 출시한다.

사용법:
    python tool/deploy_play.py --key <서비스계정.json> [--track alpha]

pubspec.yaml의 버전(0.2.9+15)을 읽어 버전 코드와 패치 노트
(play_store_assets/release_notes/ko-KR-<버전>.txt)를 찾는다.
업로드 중 하나라도 실패하면 수정 세션을 반영하지 않고 버린다.
"""
import argparse
import json
import pathlib
import re
import sys

import google_auth_httplib2
import httplib2
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

PACKAGE = 'ac.kumoh.kumoh_lms'
ROOT = pathlib.Path(__file__).resolve().parent.parent
BUNDLE = ROOT / 'build/app/outputs/bundle/release/app-release.aab'

# 콘솔 코드페이지와 무관하게 한글 로그가 깨지지 않게 한다.
sys.stdout.reconfigure(encoding='utf-8')


def read_version():
    text = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    match = re.search(r'^version:\s*([\d.]+)\+(\d+)\s*$', text, re.M)
    if not match:
        sys.exit('pubspec.yaml에서 버전을 찾지 못했습니다.')
    return match.group(1), int(match.group(2))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--key', required=True, help='서비스 계정 JSON 키 경로')
    parser.add_argument('--track', default='alpha',
                        help='internal / alpha(비공개 테스트) / beta / production')
    args = parser.parse_args()

    name, code = read_version()
    notes_file = ROOT / f'play_store_assets/release_notes/ko-KR-{name}.txt'
    if not notes_file.exists():
        sys.exit(f'패치 노트가 없습니다: {notes_file}')
    notes = notes_file.read_text(encoding='utf-8').strip()
    if len(notes) > 500:
        sys.exit(f'패치 노트가 500자를 넘습니다({len(notes)}자).')
    if not BUNDLE.exists():
        sys.exit('앱 번들이 없습니다. flutter build appbundle --release를 먼저 실행하세요.')

    creds = service_account.Credentials.from_service_account_file(
        args.key, scopes=['https://www.googleapis.com/auth/androidpublisher'])
    # 60MB대 번들은 업로드 뒤 서버 처리에 수 분이 걸린다. 기본 타임아웃(60초)이면
    # 응답을 기다리다 끊긴다.
    raw = httplib2.Http(timeout=900)
    # 분할 업로드는 조각마다 308(Resume Incomplete)을 받는데, httplib2는 이를
    # 리다이렉트로 오인해 Location이 없다며 실패한다.
    raw.redirect_codes = raw.redirect_codes - {308}
    http = google_auth_httplib2.AuthorizedHttp(creds, http=raw)
    api = build('androidpublisher', 'v3', http=http, cache_discovery=False)
    edits = api.edits()

    edit_id = edits.insert(packageName=PACKAGE, body={}).execute()['id']
    committed = False
    try:
        uploaded = {b['versionCode'] for b in
                    edits.bundles().list(packageName=PACKAGE, editId=edit_id)
                    .execute().get('bundles', [])}
        if uploaded and code <= max(uploaded):
            sys.exit(f'버전 코드 {code}는 이미 올라간 {max(uploaded)} 이하입니다. 버전을 올려 주세요.')

        print(f'{name} ({code}) 번들 업로드 중…')
        bundle = edits.bundles().upload(
            packageName=PACKAGE, editId=edit_id,
            media_body=MediaFileUpload(str(BUNDLE), mimetype='application/octet-stream',
                                       chunksize=8 * 1024 * 1024, resumable=True),
        ).execute(num_retries=3)
        print(f'  업로드 완료: 버전 코드 {bundle["versionCode"]}')

        edits.tracks().update(
            packageName=PACKAGE, editId=edit_id, track=args.track,
            body={'track': args.track, 'releases': [{
                'name': name,
                'versionCodes': [str(code)],
                'status': 'completed',
                'releaseNotes': [{'language': 'ko-KR', 'text': notes}],
            }]},
        ).execute()
        edits.commit(packageName=PACKAGE, editId=edit_id).execute()
        committed = True
        print(f'{args.track} 트랙에 {name} ({code}) 출시를 제출했습니다.')
    except HttpError as e:
        message = e.reason
        try:
            message = json.loads(e.content)['error']['message']
        except (ValueError, KeyError):
            pass
        sys.exit(f'Play API 오류 {e.status_code}: {message}')
    finally:
        if not committed:
            try:
                edits.delete(packageName=PACKAGE, editId=edit_id).execute()
            except HttpError:
                pass


if __name__ == '__main__':
    main()
