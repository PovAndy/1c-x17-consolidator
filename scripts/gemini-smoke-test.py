#!{PROJECT_ROOT}/.venv-gemini/bin/python
from __future__ import annotations

import asyncio
from datetime import datetime
from pathlib import Path
import json
import sys
import traceback

ROOT = Path('{PROJECT_ROOT}')
ENV_PATH = ROOT / '.env.gemini.local'
LOG_DIR = ROOT / 'logs' / 'gemini'
LOG_DIR.mkdir(parents=True, exist_ok=True)


def load_env(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    for raw in path.read_text(encoding='utf-8').splitlines():
        line = raw.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, value = line.split('=', 1)
        env[key.strip()] = value.strip()
    return env


async def run_test() -> dict[str, object]:
    from gemini_webapi import GeminiClient

    env = load_env(ENV_PATH)
    psid = env.get('GEMINI_1PSID', '')
    psidts = env.get('GEMINI_1PSIDTS', '')
    proxy = env.get('GEMINI_PROXY', '') or None

    if not psid:
        raise RuntimeError('missing GEMINI_1PSID in .env.gemini.local')

    client = GeminiClient(psid, psidts, proxy=proxy)
    try:
        await client.init(timeout=30, auto_close=True, close_delay=1, auto_refresh=True)
        models = client.list_models() or []
        response = await client.generate_content(
            'Reply with exactly: GEMINI_SMOKE_OK',
            temporary=True,
        )
        return {
            'ok': True,
            'text': str(response.text).strip(),
            'models_count': len(models),
            'models_preview': [getattr(m, 'model_name', str(m)) for m in models[:8]],
            'proxy_used': bool(proxy),
        }
    finally:
        try:
            await client.close()
        except Exception:
            pass


def main() -> int:
    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    out = LOG_DIR / f'gemini_smoke_{ts}.json'
    try:
        result = asyncio.run(run_test())
        out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({'log': str(out), 'ok': result['ok'], 'text': result['text']}, ensure_ascii=False))
        return 0
    except Exception as exc:
        result = {
            'ok': False,
            'error_type': type(exc).__name__,
            'error': str(exc),
            'traceback': traceback.format_exc(),
        }
        out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({'log': str(out), 'ok': False, 'error_type': type(exc).__name__, 'error': str(exc)}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
