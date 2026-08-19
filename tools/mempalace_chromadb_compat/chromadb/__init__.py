from __future__ import annotations

import json
import re
import sqlite3
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

__all__ = ["PersistentClient"]
__version__ = "0.0.0.dev0"
__compat_backend__ = True

_TOKEN_RE = re.compile(r"\w+", re.UNICODE)


def _tokenize(text: str) -> set[str]:
    return {m.group(0).lower() for m in _TOKEN_RE.finditer(text or "")}


def _score(query: str, doc: str) -> float:
    q = query.strip().lower()
    d = (doc or "").lower()
    if not q:
        return 0.0
    if q == d:
        return 1.0
    if q in d:
        return 0.95
    qt = _tokenize(q)
    dt = _tokenize(d)
    if not qt or not dt:
        return 0.0
    overlap = len(qt & dt)
    if not overlap:
        return 0.0
    coverage = overlap / max(len(qt), 1)
    jaccard = overlap / max(len(qt | dt), 1)
    return min(0.9, 0.75 * coverage + 0.25 * jaccard)


def _matches_where(meta: dict[str, Any], where: dict[str, Any] | None) -> bool:
    if not where:
        return True
    if "$and" in where:
        return all(_matches_where(meta, part) for part in where["$and"])
    for key, value in where.items():
        if key.startswith("$"):
            continue
        if meta.get(key) != value:
            return False
    return True


@dataclass
class _Row:
    id: str
    document: str
    metadata: dict[str, Any]
    updated_at: str


class Collection:
    def __init__(self, client: "PersistentClient", name: str):
        self._client = client
        self.name = name

    def count(self) -> int:
        with self._client._connect() as conn:
            row = conn.execute(
                "SELECT COUNT(*) FROM entries WHERE collection = ?",
                (self.name,),
            ).fetchone()
        return int(row[0] if row else 0)

    def upsert(
        self,
        *,
        ids: list[str],
        documents: list[str],
        metadatas: list[dict[str, Any]] | None = None,
        **_: Any,
    ) -> None:
        if metadatas is None:
            metadatas = [{} for _ in ids]
        if not (len(ids) == len(documents) == len(metadatas)):
            raise ValueError("ids/documents/metadatas length mismatch")
        with self._client._connect() as conn:
            for doc_id, document, metadata in zip(ids, documents, metadatas):
                conn.execute(
                    """
                    INSERT INTO entries (collection, id, document, metadata_json)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(collection, id) DO UPDATE SET
                      document = excluded.document,
                      metadata_json = excluded.metadata_json,
                      updated_at = CURRENT_TIMESTAMP
                    """,
                    (self.name, doc_id, document, json.dumps(metadata, ensure_ascii=False)),
                )

    def add(self, *, ids: list[str], documents: list[str], metadatas: list[dict[str, Any]] | None = None, **kwargs: Any) -> None:
        self.upsert(ids=ids, documents=documents, metadatas=metadatas, **kwargs)

    def get(
        self,
        *,
        ids: list[str] | None = None,
        include: list[str] | None = None,
        where: dict[str, Any] | None = None,
        limit: int | None = None,
        offset: int | None = None,
        **_: Any,
    ) -> dict[str, Any]:
        rows = self._select_rows(ids=ids)
        rows = [row for row in rows if _matches_where(row.metadata, where)]
        if offset:
            rows = rows[offset:]
        if limit is not None:
            rows = rows[:limit]
        include = include or []
        result: dict[str, Any] = {"ids": [row.id for row in rows]}
        if not include or "documents" in include:
            result["documents"] = [row.document for row in rows]
        if not include or "metadatas" in include:
            result["metadatas"] = [row.metadata for row in rows]
        return result

    def query(
        self,
        *,
        query_texts: list[str],
        n_results: int = 5,
        include: list[str] | None = None,
        where: dict[str, Any] | None = None,
        **_: Any,
    ) -> dict[str, Any]:
        include = include or []
        rows = [row for row in self._select_rows() if _matches_where(row.metadata, where)]
        ids_out: list[list[str]] = []
        docs_out: list[list[str]] = []
        metas_out: list[list[dict[str, Any]]] = []
        dists_out: list[list[float]] = []
        for query in query_texts:
            ranked = []
            for row in rows:
                score = _score(query, row.document)
                if score <= 0:
                    continue
                ranked.append((score, row))
            ranked.sort(key=lambda item: (-item[0], item[1].id))
            picked = ranked[:n_results]
            ids_out.append([row.id for _, row in picked])
            docs_out.append([row.document for _, row in picked])
            metas_out.append([row.metadata for _, row in picked])
            dists_out.append([round(1.0 - score, 6) for score, _ in picked])
        result: dict[str, Any] = {"ids": ids_out}
        if not include or "documents" in include:
            result["documents"] = docs_out
        if not include or "metadatas" in include:
            result["metadatas"] = metas_out
        if not include or "distances" in include:
            result["distances"] = dists_out
        return result

    def delete(self, *, ids: list[str] | None = None, where: dict[str, Any] | None = None, **_: Any) -> None:
        rows = self._select_rows(ids=ids)
        rows = [row for row in rows if _matches_where(row.metadata, where)]
        if not rows:
            return
        with self._client._connect() as conn:
            conn.executemany(
                "DELETE FROM entries WHERE collection = ? AND id = ?",
                [(self.name, row.id) for row in rows],
            )

    def _select_rows(self, ids: list[str] | None = None) -> list[_Row]:
        with self._client._connect() as conn:
            if ids:
                placeholders = ",".join("?" for _ in ids)
                raw = conn.execute(
                    f"SELECT id, document, metadata_json, updated_at FROM entries WHERE collection = ? AND id IN ({placeholders})",
                    [self.name, *ids],
                ).fetchall()
                order = {doc_id: i for i, doc_id in enumerate(ids)}
                raw.sort(key=lambda row: order.get(row[0], len(order)))
            else:
                raw = conn.execute(
                    "SELECT id, document, metadata_json, updated_at FROM entries WHERE collection = ? ORDER BY id",
                    (self.name,),
                ).fetchall()
        return [
            _Row(
                id=row[0],
                document=row[1],
                metadata=json.loads(row[2]) if row[2] else {},
                updated_at=row[3],
            )
            for row in raw
        ]


class PersistentClient:
    def __init__(self, *, path: str):
        self.path = str(Path(path).expanduser())
        Path(self.path).mkdir(parents=True, exist_ok=True)
        self._db_path = str(Path(self.path) / "chromadb_compat.sqlite3")
        self._init_db()

    @contextmanager
    def _connect(self) -> Iterable[sqlite3.Connection]:
        conn = sqlite3.connect(self._db_path)
        try:
            conn.execute("PRAGMA journal_mode=WAL")
            conn.execute("PRAGMA foreign_keys=ON")
            yield conn
            conn.commit()
        finally:
            conn.close()

    def _init_db(self) -> None:
        with self._connect() as conn:
            conn.execute(
                "CREATE TABLE IF NOT EXISTS collections (name TEXT PRIMARY KEY, created_at TEXT DEFAULT CURRENT_TIMESTAMP)"
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS entries (
                  collection TEXT NOT NULL,
                  id TEXT NOT NULL,
                  document TEXT NOT NULL,
                  metadata_json TEXT NOT NULL,
                  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                  PRIMARY KEY (collection, id),
                  FOREIGN KEY (collection) REFERENCES collections(name) ON DELETE CASCADE
                )
                """
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_entries_collection ON entries(collection)"
            )

    def get_or_create_collection(self, name: str) -> Collection:
        with self._connect() as conn:
            conn.execute(
                "INSERT INTO collections(name) VALUES (?) ON CONFLICT(name) DO NOTHING",
                (name,),
            )
        return Collection(self, name)

    def create_collection(self, name: str) -> Collection:
        with self._connect() as conn:
            conn.execute("INSERT INTO collections(name) VALUES (?)", (name,))
        return Collection(self, name)

    def get_collection(self, name: str) -> Collection:
        with self._connect() as conn:
            row = conn.execute("SELECT name FROM collections WHERE name = ?", (name,)).fetchone()
        if not row:
            raise KeyError(f"Collection not found: {name}")
        return Collection(self, name)

    def list_collections(self) -> list[Collection]:
        with self._connect() as conn:
            rows = conn.execute("SELECT name FROM collections ORDER BY name").fetchall()
        return [Collection(self, row[0]) for row in rows]

    def delete_collection(self, name: str) -> None:
        with self._connect() as conn:
            conn.execute("DELETE FROM collections WHERE name = ?", (name,))
