#!/usr/bin/env python3
"""로컬 Qt 문서(.qch) 색인을 질의한다 — 파일시스템을 훑지 않고.

왜 있나
-------
`C:\\Qt\\Docs` 에는 모듈별 `.qch` 가 있고, 이건 단순 압축 파일이 아니라
**키워드 색인 + 페이지 본문을 담은 SQLite DB** 다 (`qtquick.qch` = 색인 3,888행 /
페이지 1,080개). 그런데 에이전트는 이걸 모르면 `Glob` 으로 설치 트리를 훑는다 —
실측에서 그 방식이 28,515바이트를 먹었다 (findings/2026-09-18-mcp-vs-local.md §9-2).

사용법
------
    python tools/qdoc.py shadow                    # 키워드로 색인 검색
    python tools/qdoc.py blur --page rectangularshadow --show "default value"
    python tools/qdoc.py --list                    # 질의 가능한 .qch 목록

`--show` 는 정규식이고, 매칭 주변만 잘라서 돌려준다. 페이지 전체를 뱉지 않는다.
"""

from __future__ import annotations

import argparse
import re
import sqlite3
import sys
import zlib
from pathlib import Path

# 문서 루트. Qt Creator 는 Docs/ 가 아니라 Tools/ 아래에 자기 문서를 둔다.
DEFAULT_ROOTS = [
    Path("C:/Qt/Docs"),
    Path("C:/Qt/Tools/QtCreator/share/doc/qtcreator"),
    Path.home() / "Qt/Docs",
]


def find_qch(roots: list[Path], version_hint: str | None) -> list[Path]:
    out: list[Path] = []
    for root in roots:
        if not root.is_dir():
            continue
        for qch in sorted(root.rglob("*.qch")):
            if version_hint and version_hint not in str(qch) and root.name != "qtcreator":
                continue
            out.append(qch)
    return out


def page_text(db: sqlite3.Connection, like: str) -> tuple[str, str] | None:
    # `.html` 로 한정해야 한다. 그러지 않으면 같은 이름의 이미지가 먼저 잡힌다
    # (예: rectangularshadow → images/rectangularshadow-css-1.png 이 더 짧다).
    row = db.execute(
        "select FileId, Name from FileNameTable "
        "where Name like ? and Name like '%.html' order by length(Name) limit 1",
        (f"%{like}%",)).fetchone()
    if not row:
        return None
    data = db.execute("select Data from FileDataTable where Id=?", (row[0],)).fetchone()
    if not data:
        return None
    # qch 의 FileDataTable 은 4바이트 길이 헤더 뒤에 zlib 스트림이 온다.
    html = zlib.decompress(data[0][4:]).decode("utf-8", "replace")
    text = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html))
    return row[1], text


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass

    ap = argparse.ArgumentParser(description="로컬 Qt .qch 색인 질의")
    ap.add_argument("keyword", nargs="?", help="색인에서 찾을 이름 (부분 일치)")
    ap.add_argument("--page", help="본문을 열 페이지 파일명 (부분 일치)")
    ap.add_argument("--show", help="본문에서 뽑을 정규식")
    ap.add_argument("--context", type=int, default=160, help="--show 매칭 주변 글자 수")
    ap.add_argument("--module", help="특정 .qch 만 (예: qtquick, qtcreator)")
    ap.add_argument("--version", default="Qt-6.11.1", help="문서 버전 디렉터리 힌트")
    ap.add_argument("--limit", type=int, default=10)
    ap.add_argument("--list", action="store_true", help="질의 가능한 .qch 목록")
    ap.add_argument("--grep-all", metavar="REGEX",
                    help="본문 전문 검색. IndexTable 은 API 이름만 담아서 "
                         "산문 개념('auto format on save')은 이걸로 찾아야 한다")
    args = ap.parse_args()

    qchs = find_qch(DEFAULT_ROOTS, args.version)
    if args.module:
        qchs = [q for q in qchs if args.module.lower() in q.stem.lower()]

    if args.list:
        print(f"{len(qchs)}개 .qch")
        for q in qchs:
            print("  ", q.stem)
        return 0

    if not qchs:
        print("질의할 .qch 를 찾지 못했습니다. --version / --module 을 확인하세요.",
              file=sys.stderr)
        return 1

    if args.grep_all:
        if not args.module:
            print("--grep-all 은 --module 과 함께 쓴다. 지정하지 않으면 50개 .qch 를 "
                  "전부 훑어 엉뚱한 페이지가 걸린다(실측: qtdoc/functions.html 3,279B).",
                  file=sys.stderr)
            return 2
        pat = re.compile(args.grep_all, re.I)
        shown = 0
        for qch in qchs:
            try:
                db = sqlite3.connect(f"file:{qch}?mode=ro", uri=True)
                rows = db.execute(
                    "select f.Name, d.Data from FileNameTable f "
                    "join FileDataTable d on d.Id = f.FileId "
                    "where f.Name like '%.html'").fetchall()
            except sqlite3.Error:
                continue
            for name, blob in rows:
                try:
                    html = zlib.decompress(blob[4:]).decode("utf-8", "replace")
                except zlib.error:
                    continue
                text = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html))
                m = pat.search(text)
                if not m:
                    continue
                s = max(0, m.start() - 40)
                print(f"  [{qch.stem}/{name}] …{text[s:m.end() + args.context]}…")
                shown += 1
                if shown >= args.limit:
                    return 0
        if not shown:
            print(f"'{args.grep_all}' 전문 검색 결과 없음", file=sys.stderr)
            return 1
        return 0

    if args.page:
        for qch in qchs:
            try:
                db = sqlite3.connect(f"file:{qch}?mode=ro", uri=True)
                hit = page_text(db, args.page)
            except sqlite3.Error:
                continue
            if not hit:
                continue
            name, text = hit
            if not args.show:
                print(f"{name} ({len(text):,}자). --show 로 범위를 좁히세요.")
                return 0
            for m in re.finditer(args.show, text, re.I):
                s = max(0, m.start() - args.context // 3)
                print(f"[{name}] …{text[s:m.end() + args.context]}…")
                return 0
            print(f"[{name}] '{args.show}' 매칭 없음", file=sys.stderr)
            return 1
        print(f"'{args.page}' 페이지를 찾지 못했습니다.", file=sys.stderr)
        return 1

    if not args.keyword:
        ap.print_usage()
        return 2

    shown = 0
    for qch in qchs:
        try:
            db = sqlite3.connect(f"file:{qch}?mode=ro", uri=True)
            rows = db.execute(
                "select distinct i.Name, f.Name from IndexTable i "
                "join FileNameTable f on f.FileId = i.FileId "
                "where i.Name like ? order by length(i.Name) limit ?",
                (f"%{args.keyword}%", args.limit)).fetchall()
        except sqlite3.Error:
            continue
        for name, page in rows:
            print(f"  {name:32} {page}")
            shown += 1
            if shown >= args.limit:
                return 0
    if not shown:
        print(f"'{args.keyword}' 색인 결과 없음", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
