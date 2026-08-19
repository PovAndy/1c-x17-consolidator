#!/usr/bin/env python3
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import json
import sys

ROOT = Path('{PROJECT_ROOT}')
ENV_PATH = ROOT / '.env.gemini.local'
OUT_PATH = ROOT / 'mcp' / 'gemini-browser-bridge.cookies.json'


def load_env(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    for raw in path.read_text(encoding='utf-8').splitlines():
        line = raw.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, value = line.split('=', 1)
        env[key.strip()] = value.strip()
    return env


def main() -> int:
    if not ENV_PATH.exists():
        print(f'missing env file: {ENV_PATH}', file=sys.stderr)
        return 2

    env = load_env(ENV_PATH)
    psid = env.get('GEMINI_1PSID', '')
    papisid = env.get('GEMINI_1PAPISID', '')
    psidts = env.get('GEMINI_1PSIDTS', '')

    if not psid:
        print('missing GEMINI_1PSID in .env.gemini.local', file=sys.stderr)
        return 2

    cookies = [
        {
            'name': '__Secure-1PSID',
            'value': psid,
            'httpOnly': True,
            'secure': True,
            'sameSite': 'None',
            'path': '/',
            'domain': '.google.com',
        }
    ]

    if papisid:
        cookies.append(
            {
                'name': '__Secure-1PAPISID',
                'value': papisid,
                'httpOnly': True,
                'secure': True,
                'sameSite': 'Lax',
                'path': '/',
                'domain': '.google.com',
            }
        )

    if psidts:
        cookies.append(
            {
                'name': '__Secure-1PSIDTS',
                'value': psidts,
                'httpOnly': True,
                'secure': True,
                'sameSite': 'Lax',
                'path': '/',
                'domain': '.google.com',
            }
        )

    payload = {
        'service': 'gemini-browser-bridge',
        'source': '.env.gemini.local',
        'updated_at': datetime.now(timezone.utc).astimezone().isoformat(timespec='seconds'),
        'domain': '.google.com',
        'cookies': cookies,
        'notes': {
            'generated_from': str(ENV_PATH),
            'do_not_commit_real_secret_file': True,
        },
    }

    OUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'generated': str(OUT_PATH), 'cookie_count': len(cookies)}, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
