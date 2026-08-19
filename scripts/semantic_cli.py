#!/usr/bin/env python3
"""Lightweight semantic CLI for the EPF1129 1C project.

Purpose:
- compact project overview without loading large files into model context;
- semantic navigation for forms, commands, events and BSL handlers;
- stable local alternative to repeated raw text search.
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator


NS = {"x": "http://v8.1c.ru/8.3/xcf/logform"}
BSL_EXTENSIONS = {".bsl"}
XML_EXTENSIONS = {".xml"}
DEFAULT_MAX_RESULTS = 20


@dataclass
class ProcessingLayout:
    project_root: Path
    src_root: Path
    object_root: Path
    object_module: Path
    forms_root: Path


@dataclass
class FormInfo:
    name: str
    form_xml: Path
    module_bsl: Path | None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Semantic CLI for epf1129 1C project",
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Project root, defaults to epf1129 directory",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("overview", help="Project overview")
    subparsers.add_parser("forms", help="List available forms")
    subparsers.add_parser("version", help="Show processing version and title")

    commands_parser = subparsers.add_parser("commands", help="List form commands")
    commands_parser.add_argument("--form", help="Form name")

    events_parser = subparsers.add_parser("events", help="List form events")
    events_parser.add_argument("--form", required=True, help="Form name")
    events_parser.add_argument(
        "--items",
        action="store_true",
        help="Include nested child item events",
    )

    defs_parser = subparsers.add_parser(
        "defs",
        help="List procedure/function definitions",
    )
    defs_parser.add_argument(
        "--module",
        choices=["object", "forms", "all"],
        default="all",
        help="Definition scope",
    )
    defs_parser.add_argument("--form", help="Form name when --module=forms")

    find_parser = subparsers.add_parser(
        "find-handler",
        help="Find symbol usages in BSL/XML files",
    )
    find_parser.add_argument("symbol", help="Symbol name to search")
    find_parser.add_argument(
        "--max-results",
        type=int,
        default=DEFAULT_MAX_RESULTS,
        help="Max output lines",
    )

    return parser.parse_args()


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def detect_layout(project_root: Path) -> ProcessingLayout:
    project_root = project_root.resolve()
    src_root = project_root / "src"
    if not src_root.is_dir():
        fail(f"src root not found: {src_root}")

    object_modules = sorted(src_root.glob("*/Ext/ObjectModule.bsl"))
    if not object_modules:
        fail(f"ObjectModule.bsl not found under {src_root}")
    object_module = object_modules[0]
    object_root = object_module.parents[1]
    forms_root = object_root / "Forms"
    if not forms_root.is_dir():
        fail(f"Forms root not found: {forms_root}")

    return ProcessingLayout(
        project_root=project_root,
        src_root=src_root,
        object_root=object_root,
        object_module=object_module,
        forms_root=forms_root,
    )


def list_forms(layout: ProcessingLayout) -> list[FormInfo]:
    result: list[FormInfo] = []
    for form_dir in sorted(layout.forms_root.iterdir()):
        if not form_dir.is_dir():
            continue
        form_xml = form_dir / "Ext" / "Form.xml"
        module_bsl = form_dir / "Ext" / "Form" / "Module.bsl"
        if not form_xml.is_file():
            continue
        result.append(
            FormInfo(
                name=form_dir.name,
                form_xml=form_xml,
                module_bsl=module_bsl if module_bsl.is_file() else None,
            )
        )
    return result


def get_form(layout: ProcessingLayout, form_name: str) -> FormInfo:
    for form in list_forms(layout):
        if form.name == form_name:
            return form
    fail(f"form not found: {form_name}")


def parse_xml(path: Path) -> ET.Element:
    return ET.parse(path).getroot()


def local_tag(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def first_text(node: ET.Element | None) -> str:
    if node is None:
        return ""
    texts = []
    for chunk in node.itertext():
        value = chunk.strip()
        if value:
            texts.append(value)
    return normalize_display_text(" ".join(texts))


def normalize_display_text(value: str) -> str:
    value = value.strip()
    value = re.sub(r"^ru\s+", "", value)
    return value


def child_text(node: ET.Element, child_name: str) -> str:
    return first_text(node.find(f"x:{child_name}", NS))


def parse_version(layout: ProcessingLayout) -> tuple[str, str]:
    text = layout.object_module.read_text(encoding="utf-8")
    version_match = re.search(
        r'Функция\s+Адапт_ВерсияОбработки\(\)\s+Экспорт.*?Возврат\s+"([^"]+)"',
        text,
        re.S,
    )
    version = version_match.group(1) if version_match else "<not found>"
    title_block_match = re.search(
        r"Функция\s+Адапт_ЗаголовокОбработки\(\)\s+Экспорт(.*?)КонецФункции",
        text,
        re.S,
    )
    title = "<not found>"
    if title_block_match:
        return_match = re.search(r"Возврат\s+(.+?);", title_block_match.group(1), re.S)
        if return_match:
            expr = return_match.group(1)
            parts = re.findall(r'"([^"]*)"', expr)
            if parts:
                if "Адапт_ВерсияОбработки()" in expr and len(parts) >= 2:
                    title = parts[0] + version + parts[1]
                else:
                    title = "".join(parts)
                title = normalize_display_text(title)
    return version, title


def parse_commands(form: FormInfo) -> list[dict[str, str]]:
    root = parse_xml(form.form_xml)
    commands = root.find("x:Commands", NS)
    result = []
    if commands is None:
        return result
    for idx, command in enumerate(commands.findall("x:Command", NS), 1):
        result.append(
            {
                "index": str(idx),
                "title": child_text(command, "Title"),
                "tooltip": child_text(command, "ToolTip"),
                "action": child_text(command, "Action"),
                "representation": child_text(command, "Representation"),
            }
        )
    return result


def iter_event_nodes(events_node: ET.Element | None) -> Iterator[dict[str, str]]:
    if events_node is None:
        return
    for event in events_node.findall("x:Event", NS):
        yield {
            "name": event.attrib.get("name", ""),
            "handler": first_text(event),
        }


def describe_item(item: ET.Element) -> str:
    tag = local_tag(item.tag)
    datapath = child_text(item, "DataPath")
    title = child_text(item, "Title")
    action = child_text(item, "CommandName") or child_text(item, "Action")
    parts = [tag]
    if title:
        parts.append(f"title={title}")
    if datapath:
        parts.append(f"data={datapath}")
    if action:
        parts.append(f"action={action}")
    return " | ".join(parts)


def collect_nested_events(node: ET.Element, path_prefix: str = "") -> list[dict[str, str]]:
    result: list[dict[str, str]] = []
    for child in list(node):
        label = describe_item(child)
        current_path = f"{path_prefix}/{label}" if path_prefix else label
        events = child.find("x:Events", NS)
        for event in iter_event_nodes(events):
            result.append(
                {
                    "scope": current_path,
                    "event": event["name"],
                    "handler": event["handler"],
                }
            )
        child_items = child.find("x:ChildItems", NS)
        if child_items is not None:
            result.extend(collect_nested_events(child_items, current_path))
    return result


def parse_events(form: FormInfo, include_items: bool) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    root = parse_xml(form.form_xml)
    form_events = list(iter_event_nodes(root.find("x:Events", NS)))
    item_events: list[dict[str, str]] = []
    if include_items:
        child_items = root.find("x:ChildItems", NS)
        if child_items is not None:
            item_events = collect_nested_events(child_items)
    return form_events, item_events


def iter_definitions(path: Path) -> Iterator[tuple[int, str, str]]:
    pattern = re.compile(r"^\s*(Процедура|Функция)\s+([A-Za-zА-Яа-я0-9_]+)")
    for idx, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        match = pattern.search(line)
        if match:
            yield idx, match.group(1), match.group(2)


def iter_search_files(layout: ProcessingLayout, module_scope: str, form_name: str | None = None) -> Iterable[Path]:
    if module_scope == "object":
        return [layout.object_module]
    if module_scope == "forms":
        if form_name:
            form = get_form(layout, form_name)
            return [form.module_bsl] if form.module_bsl else []
        return [form.module_bsl for form in list_forms(layout) if form.module_bsl]

    files: list[Path] = [layout.object_module]
    files.extend(form.module_bsl for form in list_forms(layout) if form.module_bsl)
    return files


def iter_symbol_hits(layout: ProcessingLayout, symbol: str) -> Iterator[tuple[Path, int, str]]:
    pattern = re.compile(rf"\b{re.escape(symbol)}\b")
    for path in sorted(layout.object_root.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix.lower() not in BSL_EXTENSIONS | XML_EXTENSIONS:
            continue
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            continue
        for idx, line in enumerate(lines, 1):
            if pattern.search(line):
                yield path, idx, line.strip()


def print_overview(layout: ProcessingLayout) -> None:
    version, title = parse_version(layout)
    forms = list_forms(layout)
    print(f"project_root: {layout.project_root}")
    print(f"object: {layout.object_root.name}")
    print(f"version: {version}")
    print(f"title: {title}")
    print(f"forms: {len(forms)}")
    print("")
    for form in forms:
        commands = parse_commands(form)
        root_events, _ = parse_events(form, include_items=False)
        defs = list(iter_definitions(form.module_bsl)) if form.module_bsl else []
        print(
            f"- {form.name}: commands={len(commands)} root_events={len(root_events)} module_defs={len(defs)}"
        )


def print_forms(layout: ProcessingLayout) -> None:
    for form in list_forms(layout):
        module_path = form.module_bsl.relative_to(layout.project_root) if form.module_bsl else "<missing>"
        print(f"{form.name}\t{form.form_xml.relative_to(layout.project_root)}\t{module_path}")


def print_version(layout: ProcessingLayout) -> None:
    version, title = parse_version(layout)
    print(f"version: {version}")
    print(f"title: {title}")
    print(f"object_module: {layout.object_module.relative_to(layout.project_root)}")


def print_commands(layout: ProcessingLayout, form_name: str | None) -> None:
    forms = [get_form(layout, form_name)] if form_name else list_forms(layout)
    for idx, form in enumerate(forms):
        if idx:
            print("")
        print(f"[{form.name}]")
        commands = parse_commands(form)
        for command in commands:
            action = command["action"] or "<empty>"
            title = command["title"] or "<empty>"
            print(f"- #{command['index']} action={action} title={title}")


def print_events(layout: ProcessingLayout, form_name: str, include_items: bool) -> None:
    form = get_form(layout, form_name)
    root_events, item_events = parse_events(form, include_items=include_items)
    print(f"[{form.name}] root_events={len(root_events)}")
    for event in root_events:
        handler = event["handler"] or "<implicit>"
        print(f"- form event={event['name']} handler={handler}")
    if include_items:
        print("")
        print(f"[{form.name}] item_events={len(item_events)}")
        for event in item_events:
            handler = event["handler"] or "<implicit>"
            print(f"- {event['scope']} :: event={event['event']} handler={handler}")


def print_defs(layout: ProcessingLayout, module_scope: str, form_name: str | None) -> None:
    files = list(iter_search_files(layout, module_scope, form_name))
    for file_index, path in enumerate(files):
        if path is None:
            continue
        defs = list(iter_definitions(path))
        if file_index:
            print("")
        print(f"[{path.relative_to(layout.project_root)}] defs={len(defs)}")
        for line_no, kind, name in defs:
            print(f"- {line_no}: {kind} {name}")


def print_find_handler(layout: ProcessingLayout, symbol: str, max_results: int) -> None:
    count = 0
    for path, line_no, line in iter_symbol_hits(layout, symbol):
        print(f"{path.relative_to(layout.project_root)}:{line_no}: {line}")
        count += 1
        if count >= max_results:
            break
    if count == 0:
        print(f"no hits: {symbol}")
    else:
        print(f"-- hits shown: {count}")


def main() -> None:
    args = parse_args()
    layout = detect_layout(args.project_root)

    if args.command == "overview":
        print_overview(layout)
    elif args.command == "forms":
        print_forms(layout)
    elif args.command == "version":
        print_version(layout)
    elif args.command == "commands":
        print_commands(layout, args.form)
    elif args.command == "events":
        print_events(layout, args.form, args.items)
    elif args.command == "defs":
        print_defs(layout, args.module, args.form)
    elif args.command == "find-handler":
        print_find_handler(layout, args.symbol, args.max_results)
    else:
        fail(f"unsupported command: {args.command}")


if __name__ == "__main__":
    main()
