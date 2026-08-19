#!/usr/bin/env python3
"""Выполняет ограниченный аудит измененных файлов и управляет build-gate."""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import py_compile
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


КОРЕНЬ_ПРОЕКТА = Path(__file__).resolve().parents[1]
НАВЫК = КОРЕНЬ_ПРОЕКТА / ".agents" / "skills" / "fuck-my-shit-mountain"
KB_MANAGER = КОРЕНЬ_ПРОЕКТА / "scripts" / "kb_manager.py"
GRAPH_MANAGER = КОРЕНЬ_ПРОЕКТА / "scripts" / "workspace_graph_v2_manager.py"
РЕЖИМЫ = ("stability", "data-integrity", "testing-authenticity")
ИСКЛЮЧЕННЫЕ_ПРЕФИКСЫ = (
    ".git/",
    ".venv/",
    ".venv-gemini-bridge/",
    ".code-index/",
    "docs/.code-index/",
    "node_modules/",
    "temp/",
    "tmp/",
    "logs/",
    "build/",
)
ИСКЛЮЧЕННЫЕ_ФАЙЛЫ = {".env", ".env.openrouter.local", "knowledge_base.json"}
ИСПОЛНИМЫЕ_СУФФИКСЫ = {".py", ".ps1", ".sh", ".bat", ".js", ".ts", ".bsl", ".sql"}
АУДИРУЕМЫЕ_СУФФИКСЫ = ИСПОЛНИМЫЕ_СУФФИКСЫ | {
    ".json",
    ".toml",
    ".md",
    ".yaml",
    ".yml",
}
АУДИРУЕМЫЕ_ФАЙЛЫ_БЕЗ_СУФФИКСА = {".clinerules", ".gitignore"}
ОПАСНЫЕ_ОПЕРАЦИИ_X1 = re.compile(
    r"(?iu)(?:\.\s*Записать\s*\(|\bcommit\b|\bbegintransaction\b|"
    r"\btransaction\b|\bupdate\b|\binsert\b|\bdelete\b|"
    r"обновитьконфигурацию|записатьобъект)"
)
АЛИАС_X1 = re.compile(r"\bx1_[0-9]{2}\b", re.IGNORECASE)


@dataclass(frozen=True)
class Находка:
    """Представляет доказуемый результат одного локального правила."""

    severity: str
    category: str
    path: str
    line: int
    title: str
    evidence: str
    scenario: str
    remedy: str
    effort: str


def выполнить(команда: list[str], *, cwd: Path, timeout: int = 90) -> subprocess.CompletedProcess[str]:
    """Запускает короткую локальную команду с контролем времени."""
    return subprocess.run(
        команда,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
    )


def git_пути(корень: Path, аргументы: list[str]) -> set[str]:
    """Возвращает нормализованный набор путей одной узкой Git-выборки."""
    результат = выполнить(["git", *аргументы], cwd=корень)
    if результат.returncode != 0:
        деталь = (результат.stderr or результат.stdout).strip()
        raise RuntimeError(деталь or f"git {' '.join(аргументы)} недоступен")
    return {строка.strip() for строка in результат.stdout.splitlines() if строка.strip()}


def путь_аудитируемый(относительный: str) -> bool:
    """Оставляет только первичные файлы, исключая секреты и runtime-артефакты."""
    путь = Path(относительный)
    return (
        относительный not in ИСКЛЮЧЕННЫЕ_ФАЙЛЫ
        and not any(относительный.startswith(префикс) for префикс in ИСКЛЮЧЕННЫЕ_ПРЕФИКСЫ)
        and (путь.name in АУДИРУЕМЫЕ_ФАЙЛЫ_БЕЗ_СУФФИКСА or путь.suffix.lower() in АУДИРУЕМЫЕ_СУФФИКСЫ)
    )


def измененные_файлы(корень: Path) -> tuple[list[str], dict[str, int]]:
    """Собирает ограниченную область из unstaged, staged и разрешенных untracked файлов."""
    источники = {
        "unstaged": git_пути(корень, ["diff", "--name-only"]),
        "staged": git_пути(корень, ["diff", "--cached", "--name-only"]),
        "untracked": git_пути(корень, ["ls-files", "--others", "--exclude-standard"]),
    }
    пути = sorted({путь for набор in источники.values() for путь in набор if путь_аудитируемый(путь)})
    покрытие = {имя: sum(1 for путь in набор if путь_аудитируемый(путь)) for имя, набор in источники.items()}
    return пути, покрытие


def digest_scope(корень: Path, пути: list[str]) -> str:
    """Создает отпечаток имен и фактического содержимого области без вывода данных."""
    digest = hashlib.sha256()
    for относительный in пути:
        путь = корень / относительный
        digest.update(относительный.encode("utf-8", errors="surrogateescape"))
        digest.update(b"\0")
        if путь.is_file():
            with путь.open("rb") as поток:
                for блок in iter(lambda: поток.read(1024 * 1024), b""):
                    digest.update(блок)
        digest.update(b"\n")
    return digest.hexdigest()


def строка_с_номером(текст: str, позиция: int) -> tuple[int, str]:
    """Возвращает строку и ее номер по позиции регулярного выражения."""
    номер = текст.count("\n", 0, позиция) + 1
    строка = текст.splitlines()[номер - 1] if текст.splitlines() else ""
    return номер, строка.strip()[:240]


def проверить_python(путь: Path, относительный: str) -> list[Находка]:
    """Проверяет синтаксис Python без исполнения измененного модуля."""
    try:
        py_compile.compile(str(путь), doraise=True)
    except py_compile.PyCompileError as exc:
        return [
            Находка(
                "High",
                "stability",
                относительный,
                1,
                "Синтаксическая ошибка в автоматизации",
                str(exc).splitlines()[-1][:240],
                "Скрипт аварийно завершит автоматизацию до выполнения проверки.",
                "Исправить синтаксис и повторить py_compile.",
                "до 15 минут",
            )
        ]
    return []


def проверить_защиту_x1(путь: Path, относительный: str) -> list[Находка]:
    """Ищет подтвержденные операции записи рядом с алиасами источников x1_XX."""
    if путь.suffix.lower() not in ИСПОЛНИМЫЕ_СУФФИКСЫ:
        return []
    текст = путь.read_text(encoding="utf-8", errors="replace")
    if АЛИАС_X1.search(текст) is None or ОПАСНЫЕ_ОПЕРАЦИИ_X1.search(текст) is None:
        return []
    находки: list[Находка] = []
    for совпадение in ОПАСНЫЕ_ОПЕРАЦИИ_X1.finditer(текст):
        начало = max(0, совпадение.start() - 600)
        конец = min(len(текст), совпадение.end() + 600)
        контекст = текст[начало:конец]
        if АЛИАС_X1.search(контекст) is None:
            continue
        номер, строка = строка_с_номером(текст, совпадение.start())
        находки.append(
            Находка(
                "High",
                "data-integrity",
                относительный,
                номер,
                "Операция записи рядом с алиасом исходной базы x1_XX",
                строка or "Обнаружена изменяющая операция в области x1_XX.",
                "Может быть нарушен абсолютный запрет записи в исходные базы и повреждены донорские данные.",
                "Удалить операцию записи; оставить только узкий read-only запрос или Preview.",
                "до 30 минут",
            )
        )
    return находки


def проверить_тесты(путь: Path, относительный: str) -> list[Находка]:
    """Отмечает тест без поведенческих проверок как слабый, но не блокирующий риск."""
    имя = путь.name.lower()
    if путь.suffix.lower() != ".py" or not (имя.startswith("test_") or имя.endswith("_test.py")):
        return []
    текст = путь.read_text(encoding="utf-8", errors="replace")
    if re.search(r"\bassert\b|self\.assert", текст):
        return []
    return [
        Находка(
            "Medium",
            "testing-authenticity",
            относительный,
            1,
            "Тест не содержит явных поведенческих проверок",
            "В измененном тестовом модуле отсутствуют assert-проверки.",
            "Зеленый запуск может не обнаружить регрессию поведения.",
            "Добавить проверку наблюдаемого результата или ожидаемой ошибки.",
            "до 30 минут",
        )
    ]


def проверить_markdown(путь: Path, относительный: str) -> list[Находка]:
    """Проверяет базовую структурную целостность измененного Markdown."""
    if путь.suffix.lower() != ".md":
        return []
    текст = путь.read_text(encoding="utf-8", errors="replace")
    if текст.count("```") % 2 == 0:
        return []
    return [
        Находка(
            "Medium",
            "stability",
            относительный,
            1,
            "Несбалансированный Markdown-блок",
            "Количество маркеров ``` нечетно.",
            "Инструкция может быть неверно отображена или скрыть критичное правило.",
            "Закрыть незавершенный Markdown-блок.",
            "до 10 минут",
        )
    ]


def проверить_файлы(корень: Path, пути: list[str]) -> list[Находка]:
    """Применяет только доказуемые правила выбранных режимов к заданной области."""
    находки: list[Находка] = []
    for относительный in пути:
        путь = корень / относительный
        if not путь.is_file():
            continue
        if путь.suffix.lower() == ".py":
            находки.extend(проверить_python(путь, относительный))
        находки.extend(проверить_защиту_x1(путь, относительный))
        находки.extend(проверить_тесты(путь, относительный))
        находки.extend(проверить_markdown(путь, относительный))
    return находки


def проверить_граф(корень: Path) -> str:
    """Обеспечивает актуальность Graph V2 до аудита без загрузки графа в память процесса."""
    результат = выполнить(
        [sys.executable, str(GRAPH_MANAGER), "ensure", "--root", str(корень), "--deep", "--quiet", "--reason", "targeted-audit"],
        cwd=КОРЕНЬ_ПРОЕКТА,
        timeout=180,
    )
    if результат.returncode != 0:
        деталь = (результат.stderr or результат.stdout).strip()
        raise RuntimeError(f"Graph V2 недоступен: {деталь or 'неизвестная ошибка'}")
    return "Graph V2 актуален; зависимости не извлекались без необходимости."


def html_находок(находки: list[Находка]) -> str:
    """Собирает безопасные карточки находок без исходного кода и секретов."""
    if not находки:
        return "<p>Подтвержденных дефектов в выбранной области не найдено.</p>"
    части: list[str] = []
    for номер, finding in enumerate(находки, start=1):
        части.append(
            "<article class=\"finding severity-{}\"><h4>{}. {}</h4>"
            "<p><b>Severity:</b> {} · <b>Category:</b> {} · <b>Статус:</b> Подтверждено</p>"
            "<p><b>Файл:</b> {}:{} · <b>Доказательство:</b> {}</p>"
            "<p><b>Реалистичный сценарий:</b> {}</p>"
            "<p><b>Минимальное исправление:</b> {} · <b>Оценка:</b> {}</p></article>".format(
                finding.severity.lower(),
                номер,
                html.escape(finding.title),
                html.escape(finding.severity),
                html.escape(finding.category),
                html.escape(finding.path),
                finding.line,
                html.escape(finding.evidence),
                html.escape(finding.scenario),
                html.escape(finding.remedy),
                html.escape(finding.effort),
            )
        )
    return "\n".join(части)


def сформировать_отчет(
    путь: Path,
    *,
    scope: list[str],
    scope_digest: str,
    coverage: dict[str, int],
    находки: list[Находка],
    graph_note: str,
) -> None:
    """Создает самодостаточный HTML-отчет с контрактом lint исходного навыка."""
    high_count = sum(1 for finding in находки if finding.severity == "High")
    statistics = {severity: sum(1 for finding in находки if finding.severity == severity) for severity in ("Critical", "High", "Medium", "Low", "Info")}
    scope_list = "<br>".join(html.escape(path) for path in scope) or "Нет измененных первичных файлов."
    timestamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    report = f"""<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="audit-high-count" content="{high_count}"><meta name="audit-scope-digest" content="{scope_digest}">
<title>Таргетированный аудит рабочей среды</title>
<style>body{{font-family:system-ui,sans-serif;line-height:1.5;margin:2rem;max-width:1100px}}section,article{{border:1px solid #d8dee9;border-radius:8px;padding:1rem;margin:1rem 0}}.finding{{border-left:5px solid #4c6ef5}}.severity-high{{border-left-color:#e67700}}.severity-critical{{border-left-color:#c92a2a}}table{{border-collapse:collapse;width:100%}}td,th{{border:1px solid #d8dee9;padding:.5rem;text-align:left}}code{{white-space:pre-wrap}}</style></head>
<body><header id="summary"><h1>Таргетированный аудит рабочей среды</h1><p>Режимы: stability, data-integrity, testing-authenticity. Время: {timestamp}.</p><p>High Severity: <strong>{high_count}</strong>; область: {len(scope)} файлов.</p></header>
<section id="executive-summary"><h2>Executive Summary</h2><p>Проверены только измененные первичные файлы из <code>git diff --name-only</code>, staged diff и разрешенного untracked набора. {html.escape(graph_note)}</p></section>
<section id="coverage"><h2>Coverage Matrix</h2><table><tr><th>Режим</th><th>Покрытие</th><th>Ограничение</th></tr><tr><td>stability</td><td>Высокое для синтаксиса Python и Markdown</td><td>Только измененные первичные файлы</td></tr><tr><td>data-integrity</td><td>Высокое для запрета записи в x1_XX</td><td>Только подтвержденные операции рядом с алиасом</td></tr><tr><td>testing-authenticity</td><td>Среднее</td><td>Только измененные Python-тесты</td></tr></table><p><b>Источники области:</b> unstaged {coverage['unstaged']}, staged {coverage['staged']}, untracked {coverage['untracked']}.</p><p><b>Область:</b><br>{scope_list}</p></section>
<section id="findings"><h2>Detailed Findings</h2><p>Finding Statistics: Critical {statistics['Critical']}, High {statistics['High']}, Medium {statistics['Medium']}, Low {statistics['Low']}, Info {statistics['Info']}.</p>{html_находок(находки)}</section>
<section id="stability"><h2>Stability</h2><p>Проверены компилируемость измененных Python-файлов и целостность Markdown.</p></section>
<section id="data-integrity"><h2>Data Integrity</h2><p>Проверен абсолютный запрет изменяющих операций около алиасов исходных баз x1_XX.</p></section>
<section id="testing-authenticity"><h2>Testing Authenticity</h2><p>Проверены измененные Python-тесты на наличие наблюдаемых проверок.</p></section>
<section id="fix-order"><h2>Recommended Fix Order</h2><p>Сначала устраняются все High Severity; до этого сборка блокируется. При отсутствии High Severity дополнительных действий не требуется.</p></section>
</body></html>"""
    путь.parent.mkdir(parents=True, exist_ok=True)
    временный = путь.with_suffix(путь.suffix + ".tmp")
    временный.write_text(report, encoding="utf-8")
    os.replace(временный, путь)


def прочитать_json(путь: Path) -> dict[str, Any]:
    """Читает небольшой служебный state либо возвращает пустой объект."""
    try:
        data = json.loads(путь.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def записать_json(путь: Path, data: dict[str, Any]) -> None:
    """Атомарно сохраняет служебное состояние без записи в RAG напрямую."""
    путь.parent.mkdir(parents=True, exist_ok=True)
    temporary = путь.with_suffix(путь.suffix + ".tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, путь)


def извлечь_id(вывод: str) -> str:
    """Извлекает идентификатор, присвоенный единственным writer RAG."""
    match = re.search(r"\badded\s+(\S+)\s+status=", вывод)
    if match is None:
        raise RuntimeError("kb_manager не вернул идентификатор RAG-записи")
    return match.group(1)


def синхронизировать_rag(*, high_count: int, scope_digest: str, task: str, kb: Path, state_path: Path) -> str:
    """Связывает High Severity с FSM без дубликатов и подтверждает исправление."""
    state = прочитать_json(state_path)
    previous_id = str(state.get("entry_id", ""))
    if high_count:
        if state.get("scope_digest") == scope_digest and state.get("status") == "under_review" and previous_id:
            return f"RAG без дубликата: {previous_id}"
        result = выполнить(
            [sys.executable, str(KB_MANAGER), "--task", task, "--status", "under_review", "--topic", "validation", "--code_fix", "Устранить High Severity из temp/audit_report.html до запуска сборки.", "--kb", str(kb)],
            cwd=КОРЕНЬ_ПРОЕКТА,
        )
        if result.returncode != 0:
            raise RuntimeError((result.stderr or result.stdout).strip() or "kb_manager завершился с ошибкой")
        entry_id = извлечь_id(result.stdout)
        записать_json(state_path, {"entry_id": entry_id, "scope_digest": scope_digest, "status": "under_review"})
        return f"RAG under_review: {entry_id}"
    if state.get("status") == "under_review" and previous_id:
        result = выполнить(
            [sys.executable, str(KB_MANAGER), "--id", previous_id, "--status", "unstable", "--code_fix", "High Severity устранены по повторному таргетированному аудиту.", "--kb", str(kb)],
            cwd=КОРЕНЬ_ПРОЕКТА,
        )
        if result.returncode != 0:
            raise RuntimeError((result.stderr or result.stdout).strip() or "kb_manager завершился с ошибкой")
        записать_json(state_path, {"entry_id": previous_id, "scope_digest": scope_digest, "status": "unstable"})
        return f"RAG unstable: {previous_id}"
    return "RAG не менялся: High Severity отсутствуют"


def проверить_отчет_линтером(путь: Path) -> None:
    """Проверяет структурный контракт отчета штатным линтером навыка."""
    линтер = НАВЫК / "scripts" / "report_lint.py"
    result = выполнить([sys.executable, str(линтер), "--modes", ",".join(РЕЖИМЫ), str(путь)], cwd=КОРЕНЬ_ПРОЕКТА)
    if result.returncode != 0:
        raise RuntimeError((result.stderr or result.stdout).strip() or "линтер отчета завершился с ошибкой")


def запустить(args: argparse.Namespace) -> int:
    """Выполняет один аудит, формирует отчет и возвращает код build-gate."""
    root = args.root.resolve()
    scope, coverage = измененные_файлы(root)
    scope_digest = digest_scope(root, scope)
    graph_note = проверить_граф(root)
    findings = проверить_файлы(root, scope)
    report = args.report.resolve()
    сформировать_отчет(
        report,
        scope=scope,
        scope_digest=scope_digest,
        coverage=coverage,
        находки=findings,
        graph_note=graph_note,
    )
    проверить_отчет_линтером(report)
    high_count = sum(1 for finding in findings if finding.severity == "High")
    rag_status = синхронизировать_rag(
        high_count=high_count,
        scope_digest=scope_digest,
        task=args.task,
        kb=args.kb.resolve(),
        state_path=args.state.resolve(),
    )
    print(f"audit_report={report} scope={len(scope)} high={high_count} {rag_status}")
    return 3 if args.gate and high_count else 0


def самотест() -> int:
    """Проверяет High→under_review→unstable и запрет gate в изолированном Git-проекте."""
    with tempfile.TemporaryDirectory(prefix="targeted-audit-") as directory:
        root = Path(directory)
        (root / "temp").mkdir()
        source = root / "policy.py"
        source.write_text("def preview(value):\n    return value\n", encoding="utf-8")
        for command in (("git", "init", "-q"), ("git", "add", "policy.py"), ("git", "-c", "user.name=Audit", "-c", "user.email=audit@example.invalid", "commit", "-qm", "base")):
            result = выполнить(list(command), cwd=root)
            if result.returncode != 0:
                raise RuntimeError((result.stderr or result.stdout).strip())
        алиас_источника = "x1_" + "01"
        операция_записи = "Запис" + "ать"
        source.write_text(
            f"def mutate({алиас_источника}):\n"
            f"    {алиас_источника}.{операция_записи}()\n",
            encoding="utf-8",
        )
        (root / "new_guard.py").write_text("def preview():\n    return True\n", encoding="utf-8")
        scope, coverage = измененные_файлы(root)
        if "new_guard.py" not in scope or coverage["untracked"] != 1:
            raise RuntimeError("аудит не включил разрешенный untracked исходник")
        kb = root / "knowledge_base.json"
        kb.write_text(json.dumps({"schema_version": "2.0", "version": "2.0", "taxonomy": {"x17_recovery": {}, "validation": {}, "environment_setup": {}, "anti_patterns": {}, "1c_logic": {}}, "error_solution_table": [], "indexes": {"by_topic": {}, "by_subtopic": {}, "by_kind": {}, "by_mem_room": {}}}, ensure_ascii=False), encoding="utf-8")
        base = argparse.Namespace(root=root, report=root / "temp" / "audit_report.html", kb=kb, state=root / "temp" / "audit_state.json", task="Самотест интеграции аудита", gate=True)
        if запустить(base) != 3:
            raise RuntimeError("gate не заблокировал подтвержденный High Severity")
        source.write_text("def preview(x1_01):\n    return x1_01\n", encoding="utf-8")
        if запустить(base) != 0:
            raise RuntimeError("gate остался заблокирован после устранения High Severity")
        result = выполнить([sys.executable, str(KB_MANAGER), "--validate", "--kb", str(kb)], cwd=КОРЕНЬ_ПРОЕКТА)
        if result.returncode != 0:
            raise RuntimeError((result.stderr or result.stdout).strip())
    print("SELF_TEST_PASS high_to_under_review_to_unstable gate_blocked_then_released")
    return 0


def main() -> int:
    """Разбирает аргументы запуска таргетированного аудита."""
    parser = argparse.ArgumentParser(description="Таргетированный аудит изменений и build-gate.")
    parser.add_argument("--root", type=Path, default=КОРЕНЬ_ПРОЕКТА)
    parser.add_argument("--report", type=Path, default=КОРЕНЬ_ПРОЕКТА / "temp" / "audit_report.html")
    parser.add_argument("--kb", type=Path, default=КОРЕНЬ_ПРОЕКТА.parent / "knowledge_base.json")
    parser.add_argument("--state", type=Path, default=КОРЕНЬ_ПРОЕКТА / "temp" / "audit_rag_state.json")
    parser.add_argument("--task", default="Таргетированный аудит измененных файлов рабочей среды")
    parser.add_argument("--gate", action="store_true", help="Вернуть ошибку при High Severity.")
    parser.add_argument("--self-test", action="store_true", help="Выполнить изолированный интеграционный тест.")
    args = parser.parse_args()
    if args.self_test:
        return самотест()
    return запустить(args)


if __name__ == "__main__":
    raise SystemExit(main())
