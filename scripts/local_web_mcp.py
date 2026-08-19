#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import json
import re
import sys
import time
import xml.etree.ElementTree as ET
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import datetime, timezone
from html import unescape
from typing import Any
from urllib.parse import parse_qs, quote_plus, urlparse

import certifi
import requests
import urllib3
from bs4 import BeautifulSoup
from mcp.server.fastmcp import FastMCP


USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/124.0 Safari/537.36"
)
TIMEOUT = 20
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


@dataclass
class SearchItem:
    title: str
    url: str
    snippet: str


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _clean_text(text: str) -> str:
    text = unescape(text or "")
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def _requests_get(url: str) -> tuple[requests.Response, bool]:
    try:
        return (
            requests.get(
                url,
                timeout=TIMEOUT,
                headers={"User-Agent": USER_AGENT},
                verify=certifi.where(),
            ),
            True,
        )
    except requests.exceptions.SSLError:
        return (
            requests.get(
                url,
                timeout=TIMEOUT,
                headers={"User-Agent": USER_AGENT},
                verify=False,
            ),
            False,
        )


def _decode_bing_url(raw_url: str) -> str:
    if "bing.com/ck/a" not in raw_url:
        return raw_url
    try:
        parsed = urlparse(raw_url)
        encoded = parse_qs(parsed.query).get("u", [""])[0]
        if encoded.startswith("a1"):
            body = encoded[2:]
            body += "=" * (-len(body) % 4)
            return base64.b64decode(body).decode("utf-8", errors="ignore")
    except Exception:
        return raw_url
    return raw_url


def _host_matches_filters(url: str, domains: Iterable[str]) -> bool:
    domain_list = [domain.lower().strip() for domain in domains if domain and domain.strip()]
    if not domain_list:
        return True
    try:
        host = (urlparse(url).hostname or "").lower()
    except Exception:
        return False
    if not host:
        return False
    return any(host == domain or host.endswith("." + domain) for domain in domain_list)


def _unique_results(items: Iterable[SearchItem], limit: int) -> list[SearchItem]:
    seen: set[str] = set()
    results: list[SearchItem] = []
    for item in items:
        if not item.url or item.url in seen:
            continue
        seen.add(item.url)
        results.append(item)
        if len(results) >= limit:
            break
    return results


def _brave_search(query: str, limit: int = 5, site_filters: Iterable[str] | None = None) -> list[SearchItem]:
    url = f"https://search.brave.com/search?q={quote_plus(query)}"
    response = None
    for attempt in range(3):
        current_response, _ = _requests_get(url)
        if current_response.status_code != 429:
            response = current_response
            break
        if attempt < 2:
            time.sleep(2 + attempt * 3)
        response = current_response
    assert response is not None
    response.raise_for_status()

    soup = BeautifulSoup(response.text, "html.parser")
    results: list[SearchItem] = []
    filters = list(site_filters or [])

    for node in soup.select('div[data-type="web"]'):
        title_node = node.select_one("div.title")
        link_node = node.select_one("a[href]")
        snippet_node = node.select_one("div.generic-snippet .content") or node.select_one(".content")

        title = _clean_text(title_node.get_text(" ", strip=True) if title_node else "")
        href = _clean_text(link_node.get("href", "") if link_node else "")
        snippet = _clean_text(snippet_node.get_text(" ", strip=True) if snippet_node else "")
        if not title or not href:
            continue
        if not _host_matches_filters(href, filters):
            continue

        results.append(SearchItem(title=title, url=href, snippet=snippet))
        if len(results) >= limit:
            break

    return results


def _bing_search(query: str, limit: int = 5) -> list[SearchItem]:
    url = f"https://www.bing.com/search?format=rss&setlang=ru&cc=ru&q={quote_plus(query)}"
    response, _ = _requests_get(url)
    response.raise_for_status()

    results: list[SearchItem] = []

    root = ET.fromstring(response.text)
    channel = root.find("channel")
    if channel is None:
        return results

    for item in channel.findall("item"):
        title = _clean_text(item.findtext("title", default=""))
        href = _decode_bing_url(_clean_text(item.findtext("link", default="")))
        snippet = _clean_text(item.findtext("description", default=""))
        if not title or not href:
            continue
        results.append(SearchItem(title=title, url=href, snippet=snippet))
        if len(results) >= limit:
            break

    return results


def _jina_search_fallback(query: str, limit: int = 5) -> list[SearchItem]:
    url = f"https://r.jina.ai/http://www.bing.com/search?q={quote_plus(query)}"
    response, _ = _requests_get(url)
    response.raise_for_status()
    text = response.text

    items: list[SearchItem] = []
    blocks = re.split(r"\n\d+\.\s+", text)
    for block in blocks:
        lines = [line.strip() for line in block.splitlines() if line.strip()]
        if len(lines) < 2:
            continue
        title = lines[0]
        source_line = next((line for line in lines if line.startswith("URL Source: ")), "")
        if not source_line:
            continue
        source_url = source_line.replace("URL Source: ", "", 1).strip()
        snippet = _clean_text(" ".join(lines[2:6]))
        items.append(SearchItem(title=title, url=source_url, snippet=snippet))
        if len(items) >= limit:
            break
    return items


def ddg_search(query: str, limit: int = 5, site: str | None = None) -> dict[str, Any]:
    if not query.strip():
        raise ValueError("query must not be empty")
    effective_query = query.strip()
    site_filters = [site.strip()] if site and site.strip() else []
    brave_query = f"site:{site_filters[0]} {effective_query}" if site_filters else effective_query

    engines_tried: list[str] = []
    results: list[SearchItem] = []

    try:
        results = _brave_search(query=brave_query, limit=limit, site_filters=site_filters)
        engines_tried.append("brave-html")
    except Exception:
        engines_tried.append("brave-html:error")

    if not results:
        try:
            results = _bing_search(query=brave_query, limit=limit)
            if site_filters:
                results = [item for item in results if _host_matches_filters(item.url, site_filters)]
            engines_tried.append("bing-rss")
        except Exception:
            engines_tried.append("bing-rss:error")

    if not results:
        try:
            results = _jina_search_fallback(query=brave_query, limit=limit)
            if site_filters:
                results = [item for item in results if _host_matches_filters(item.url, site_filters)]
            engines_tried.append("jina-bing-fallback")
        except Exception:
            engines_tried.append("jina-bing-fallback:error")

    results = _unique_results(results, limit)
    engine = next((name for name in engines_tried if not name.endswith(":error")), "none")

    return {
        "engine": engine,
        "query": brave_query,
        "fetched_at_utc": _utc_now(),
        "count": len(results),
        "items": [item.__dict__ for item in results],
        "engines_tried": engines_tried,
    }


def fetch_url(url: str, max_chars: int = 12000) -> dict[str, Any]:
    if not url.startswith(("http://", "https://")):
        raise ValueError("url must start with http:// or https://")

    response, tls_verified = _requests_get(url)
    response.raise_for_status()
    content_type = response.headers.get("content-type", "")

    text = ""
    title = ""
    if "html" in content_type.lower():
        soup = BeautifulSoup(response.text, "html.parser")
        title = _clean_text(soup.title.get_text(" ", strip=True) if soup.title else "")
        for tag in soup(["script", "style", "noscript"]):
            tag.decompose()
        text = _clean_text(soup.get_text(" ", strip=True))
    else:
        text = response.text

    text = text[:max_chars]
    return {
        "url": url,
        "status_code": response.status_code,
        "content_type": content_type,
        "tls_verified": tls_verified,
        "title": title,
        "fetched_at_utc": _utc_now(),
        "text": text,
    }


app = FastMCP("local-web")


@app.tool(
    name="web_search",
    description=(
        "Search the public internet through the local MCP web route. "
        "Returns compact search results with title, URL and snippet."
    ),
)
def web_search(query: str, limit: int = 5, site: str | None = None) -> dict[str, Any]:
    """Search the internet via local MCP."""
    limit = max(1, min(int(limit), 10))
    return ddg_search(query=query, limit=limit, site=site)


@app.tool(
    name="web_fetch",
    description=(
        "Fetch a public web page through the local MCP web route and return "
        "compact cleaned text."
    ),
)
def web_fetch(url: str, max_chars: int = 12000) -> dict[str, Any]:
    """Fetch and normalize a web page via local MCP."""
    max_chars = max(500, min(int(max_chars), 30000))
    return fetch_url(url=url, max_chars=max_chars)


def _build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test-search", help="Run one search test and print JSON")
    parser.add_argument("--self-test-site", help="Optional site filter for --self-test-search")
    parser.add_argument("--self-test-fetch", help="Run one fetch test and print JSON")
    return parser


def main() -> int:
    parser = _build_arg_parser()
    args = parser.parse_args()

    if args.self_test_search:
        print(
            json.dumps(
                ddg_search(args.self_test_search, limit=3, site=args.self_test_site),
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    if args.self_test_fetch:
        print(json.dumps(fetch_url(args.self_test_fetch, max_chars=4000), ensure_ascii=False, indent=2))
        return 0

    app.run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
