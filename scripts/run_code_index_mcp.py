#!/usr/bin/env python3
"""Запуск MCP code-index для epf1129 через единую виртуальную среду."""

from __future__ import annotations

import os
import json
import re
import socket
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path("{PROJECT_ROOT}")
HOME = ROOT / "tools" / "code-index-mcp"
BINARY = HOME / "code-index"
CONFIG = HOME / "daemon.toml"
LOG = HOME / "daemon-run.log"
PID_FILE = HOME / "daemon.pid"
STATE_FILE = HOME / "daemon.json"
ENV_FILE = ROOT / ".env.openrouter.local"
DAEMON_HOST = "127.0.0.1"
DAEMON_PORT = 44369
WINDOWS10_PROXY = "{HTTP_PROXY}"
CODE_INDEX_SLOT_MAX = 8


def _read_env_file() -> dict[str, str]:
    values: dict[str, str] = {}
    if not ENV_FILE.exists():
        return values
    pattern = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$")
    for line in ENV_FILE.read_text(encoding="utf-8", errors="ignore").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        match = pattern.match(line)
        if not match:
            continue
        key, value = match.groups()
        if " #" in value:
            value = value.split(" #", 1)[0].rstrip()
        values[key] = value.strip().strip('"').strip("'")
    return values


def _is_placeholder(value: str) -> bool:
    stripped = value.strip().strip('"').strip("'")
    return not stripped or stripped.startswith("ВАШ_") or stripped.lower() in {"changeme", "todo"}


def _merge_no_proxy(existing: str) -> str:
    items = [item.strip() for item in existing.split(",") if item.strip()]
    for item in ("127.0.0.1", "localhost"):
        if item not in items:
            items.append(item)
    return ",".join(items)


def _without_no_proxy_hosts(existing: str, hosts: tuple[str, ...]) -> str:
    """Исключает внешние LLM-шлюзы из NO_PROXY для обязательного HTTPS-прокси."""
    blocked = {host.casefold().lstrip(".") for host in hosts if host}
    items = [item.strip() for item in existing.split(",") if item.strip()]
    return ",".join(
        item
        for item in items
        if item.casefold().lstrip(".") not in blocked
    )


def _code_index_model_pairs(values: dict[str, str]) -> list[tuple[str, str, str]]:
    pairs: list[tuple[str, str, str]] = []
    for index in range(1, CODE_INDEX_SLOT_MAX + 1):
        suffix = f"{index:02d}"
        key = values.get(f"OR_KEY_CODE_INDEX_{suffix}", "").strip()
        model = values.get(f"OR_MODEL_CODE_INDEX_{suffix}", "").strip()
        if key and model:
            pairs.append((suffix, key, model))

    legacy_key = values.get("OR_KEY_CODE_INDEX", "").strip()
    legacy_model = values.get("OR_MODEL_CODE_INDEX", "").strip()
    if legacy_key and legacy_model and not pairs:
        pairs.append(("legacy", legacy_key, legacy_model))
    return pairs


def _select_code_index_model_pair(values: dict[str, str]) -> tuple[str, str, str] | None:
    for slot, key, model in _code_index_model_pairs(values):
        if not _is_placeholder(key) and model:
            return slot, key, model
    return None


def _production_coder_config(values: dict[str, str]) -> tuple[str, str, str] | None:
    """Возвращает изолированный production-контур кодера при полной настройке."""
    base_url = values.get("CODE_INDEX_PRODUCTION_API_BASE_URL", "").strip().rstrip("/")
    model = values.get("CODE_INDEX_PRODUCTION_MODEL_ID", "").strip()
    api_key = values.get("CODE_INDEX_PRODUCTION_API_KEY", "").strip()
    if not any((base_url, model, api_key)):
        return None
    if not all((base_url, model, api_key)):
        raise RuntimeError(
            "Production-кодер должен содержать CODE_INDEX_PRODUCTION_API_BASE_URL, "
            "CODE_INDEX_PRODUCTION_MODEL_ID и CODE_INDEX_PRODUCTION_API_KEY"
        )
    parsed_url = urlparse(base_url)
    if parsed_url.scheme != "https" or parsed_url.path not in {"/api", "/v1"} or parsed_url.query:
        raise RuntimeError(
            "CODE_INDEX_PRODUCTION_API_BASE_URL должен быть HTTPS-адресом с путем /api или /v1"
        )
    return base_url, model, api_key


def _env() -> dict[str, str]:
    env = os.environ.copy()
    file_values = _read_env_file()
    for key, value in file_values.items():
        env.setdefault(key, value)
    env["CODE_INDEX_HOME"] = str(HOME)

    production = _production_coder_config(env)
    if production:
        base_url, model, api_key = production
        env["OPENROUTER_API_KEY"] = api_key
        env["OPENROUTER_MODEL_ID"] = model
        env["OPENROUTER_BASE_URL"] = base_url
        env["OPENROUTER_API_BASE"] = base_url
        env["OPENAI_API_KEY"] = api_key
        env["OPENAI_BASE_URL"] = base_url
        env["OPENAI_API_BASE"] = base_url
        env["CODE_INDEX_OPENROUTER_SLOT"] = "production"
    else:
        selected = _select_code_index_model_pair(env)
        if selected:
            slot, dedicated_key, model = selected
            env["OPENROUTER_API_KEY"] = dedicated_key
            env["OPENROUTER_MODEL_ID"] = model
            env["CODE_INDEX_OPENROUTER_SLOT"] = slot
        else:
            env.pop("OPENROUTER_API_KEY", None)
            env.pop("OPENROUTER_MODEL_ID", None)
            env.pop("CODE_INDEX_OPENROUTER_SLOT", None)
    proxy = env.get("LDS_NETWORK_PROXY_IP") or WINDOWS10_PROXY
    if proxy:
        for name in ("HTTP_PROXY", "HTTPS_PROXY", "http_proxy", "https_proxy", "ALL_PROXY", "all_proxy"):
            env[name] = proxy
    no_proxy_hosts = (urlparse(production[0]).hostname or "",) if production else ()
    env["NO_PROXY"] = _merge_no_proxy(_without_no_proxy_hosts(env.get("NO_PROXY", ""), no_proxy_hosts))
    env["no_proxy"] = _merge_no_proxy(_without_no_proxy_hosts(env.get("no_proxy", ""), no_proxy_hosts))
    return env


def _state_port() -> int:
    if not STATE_FILE.exists():
        return DAEMON_PORT
    try:
        data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        port = int(data.get("http_port") or 0)
    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        return DAEMON_PORT
    return port or DAEMON_PORT


def _run_status() -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(BINARY), "daemon", "status", "--json"],
        text=True,
        capture_output=True,
        env=_env(),
        timeout=8,
        check=False,
    )


def _port_is_open(host: str = DAEMON_HOST, port: int | None = None, timeout: float = 0.3) -> bool:
    checked_port = port or _state_port()
    try:
        with socket.create_connection((host, checked_port), timeout=timeout):
            return True
    except OSError:
        return False


def _remove_stale_pid_if_needed() -> None:
    if _port_is_open():
        return
    if PID_FILE.exists():
        try:
            PID_FILE.unlink()
        except OSError:
            pass
    if STATE_FILE.exists():
        try:
            STATE_FILE.unlink()
        except OSError:
            pass


def _ensure_daemon() -> None:
    status = _run_status()
    if status.returncode == 0:
        return
    if _port_is_open():
        return

    _remove_stale_pid_if_needed()
    HOME.mkdir(parents=True, exist_ok=True)
    log = LOG.open("a", encoding="utf-8")
    subprocess.Popen(
        [str(BINARY), "daemon", "run"],
        stdout=log,
        stderr=log,
        stdin=subprocess.DEVNULL,
        env=_env(),
        cwd=str(ROOT),
        start_new_session=True,
    )
    for _ in range(30):
        time.sleep(0.5)
        if _port_is_open() or _run_status().returncode == 0:
            return


def main() -> int:
    if not BINARY.exists():
        print(f"Не найден бинарник code-index: {BINARY}", file=sys.stderr)
        return 2
    if not CONFIG.exists():
        print(f"Не найден конфиг code-index: {CONFIG}", file=sys.stderr)
        return 2
    if "--daemon-run" in sys.argv:
        os.execve(str(BINARY), [str(BINARY), "daemon", "run"], _env())
    _ensure_daemon()
    os.execve(
        str(BINARY),
        [str(BINARY), "serve", "--config", str(CONFIG)],
        _env(),
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
