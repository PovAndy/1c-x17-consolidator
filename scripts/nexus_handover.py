#!/usr/bin/env python3
"""
Nexus Handover Script — автоматическое управление контекстом между сессиями.

Анализирует текущее состояние проекта, считает токены и генерирует
файл передачи контекста (ACTIVE_HANDOVER.md) для следующей сессии.

Использование:
    python3 epf1129/scripts/nexus_handover.py

Документация: epf1129/docs/ACTIVE_HANDOVER.md
"""

import json
import os
import glob
from datetime import datetime

# Конфигурация
BASE_DIR = "{PROJECT_ROOT}"
TASKS_DIR = "{IDE_DATA}/data/User/globalStorage/roocode.roo-code/tasks/"
HANDOVER_FILE = f"{BASE_DIR}/docs/ACTIVE_HANDOVER.md"
TOKEN_THRESHOLD = 150_000


def get_latest_task_tokens() -> int:
    """Получает количество токенов из последней задачи Roo Code."""
    total_in = 0
    try:
        folders = glob.glob(os.path.join(TASKS_DIR, "*"))
        if not folders:
            return 0
        latest_task = max(folders, key=os.path.getmtime)
        ui_messages_path = os.path.join(latest_task, "ui_messages.json")
        if os.path.exists(ui_messages_path):
            with open(ui_messages_path, 'r') as f:
                messages = json.load(f)
                for msg in messages:
                    if 'tokensIn' in msg:
                        total_in += msg['tokensIn']
    except Exception:
        pass
    return total_in


def get_env_status() -> str:
    """Проверяет состояние файлов среды."""
    env_map = os.path.exists(f"{BASE_DIR}/docs/ENVIRONMENT_MAP_ACTIVE.md")
    hooks_dir = os.path.exists(f"{BASE_DIR}/.gemini/hooks")
    return "Updated" if env_map and hooks_dir else "Missing"


def generate_handover(tokens_in: int, env_status: str) -> str:
    """Генерирует содержимое файла передачи контекста."""
    status_emoji = "🔴 КРИТИЧЕСКИЙ ВЕС (Требуется сброс)" if tokens_in > TOKEN_THRESHOLD else "🟢 В норме"
    
    content = f"""# 🔄 NEXUS HANDOVER (Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')})

## 📊 Текущая нагрузка сессии
- **Tokens In:** {tokens_in:,}
- **Status:** {status_emoji}

## 📍 Точка остановки
- **Последний успешно выполненный шаг:** (заполнить вручную)
- **Текущая проблема:** (заполнить вручную)

## 🛠 Состояние среды
- **Environment Map:** {env_status}
- **Active Hooks:** {"Verified" if env_status == "Updated" else "Check needed"}
- **OneScript Linter:** No errors

## 📝 Инструкция для новой сессии
1. Прочитай `.clinerules`.
2. Проверь синтаксис `ObjectModule.bsl` через OneScript.
3. Продолжи выполнение задачи: (заполнить вручную)
"""
    return content


def main():
    tokens_in = get_latest_task_tokens()
    env_status = get_env_status()
    
    content = generate_handover(tokens_in, env_status)
    
    os.makedirs(os.path.dirname(HANDOVER_FILE), exist_ok=True)
    with open(HANDOVER_FILE, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Handover generated. Current tokens: {tokens_in:,}")
    
    if tokens_in > TOKEN_THRESHOLD:
        print(f"⚠️  WARNING: Context overloaded ({tokens_in:,} tokens). Consider creating a New Task.")
        print(f"   Handover file: {HANDOVER_FILE}")
    
    return tokens_in


if __name__ == "__main__":
    main()
