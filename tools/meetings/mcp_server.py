#!/usr/bin/env python3
"""{{AIOS_NAME}} meetings MCP server: read-only list, search and read over the user's meeting folder.

Scribe publishes every finished meeting to <AIOS>/logs/meetings/<date-slug>/meeting.md (summary and
decisions on top, transcript below) plus transcript.md. This server lets any engine find them without a
pasted path. It never writes, never calls the network and never touches audio.

Folder: aios_MEETINGS_DIR if set, else logs/meetings next to this file's AIOS root. Older flat notes
(<date>-<slug>.md beside <date>-<slug>.transcript.md) are listed too.

Requires: Python 3.10+ with the mcp package (pip install mcp).
"""

import os
import re
import sys
from pathlib import Path

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    sys.stderr.write("meetings: the 'mcp' package is required (pip install mcp)\n")
    sys.exit(1)

ROOT = Path(os.environ.get("aios_MEETINGS_DIR") or Path(__file__).resolve().parents[2] / "logs" / "meetings")
DATE = re.compile(r"^(\d{4}-\d{2}-\d{2})")
mcp = FastMCP("meetings")


def _entries() -> list[dict]:
    """Newest first: {id, date, title, path}. id is the folder name (or the flat file stem)."""
    out = []
    if not ROOT.is_dir():
        return out
    for p in ROOT.iterdir():
        if p.is_dir() and (p / "meeting.md").is_file():
            md = p / "meeting.md"
        elif p.is_file() and p.suffix == ".md" and not p.name.endswith(".transcript.md"):
            md = p
        else:
            continue
        m = DATE.match(p.stem if p.is_file() else p.name)
        title = ""
        try:
            with open(md, encoding="utf-8") as f:
                for line in f:
                    if line.startswith("# "):
                        title = line[2:].strip()
                        break
        except OSError:
            continue
        out.append({"id": p.stem if p.is_file() else p.name, "date": m.group(1) if m else "", "title": title, "path": str(md)})
    return sorted(out, key=lambda e: (e["date"], e["id"]), reverse=True)


@mcp.tool()
def list_meetings(limit: int = 10) -> str:
    """List the user's recorded meetings, newest first: id, date, title and the path of the file to read.
    Use when the user asks about a call, meeting or conversation they recorded with Scribe."""
    items = _entries()[: max(1, min(int(limit), 50))]
    if not items:
        return f"No meetings found in {ROOT}."
    return "\n".join(f"- {e['id']} | {e['date']} | {e['title'] or '(untitled)'} | {e['path']}" for e in items)


@mcp.tool()
def search_meetings(query: str, limit: int = 5) -> str:
    """Search every meeting (summary, decisions, action items and transcript) for a word or phrase.
    Returns the best matches with a snippet and the file path. Case-insensitive, all terms must appear."""
    terms = [t for t in re.findall(r"\w+", query.lower()) if t]
    if not terms:
        return "Give at least one search word."
    hits = []
    for e in _entries():
        try:
            text = Path(e["path"]).read_text(encoding="utf-8")
        except OSError:
            continue
        low = text.lower()
        if not all(t in low for t in terms):
            continue
        i = low.find(terms[0])
        snippet = " ".join(text[max(0, i - 80): i + 160].split())
        hits.append((sum(low.count(t) for t in terms), e, snippet))
    hits.sort(key=lambda h: h[0], reverse=True)
    if not hits:
        return "No meeting matches that query."
    return "\n".join(f"- {e['id']} | {e['title'] or '(untitled)'} | {e['path']}\n  ...{s}..."
                     for _, e, s in hits[: max(1, min(int(limit), 20))])


@mcp.tool()
def read_meeting(meeting_id: str, max_chars: int = 30000) -> str:
    """Read one meeting by id (from list_meetings or search_meetings): summary and decisions first, transcript below.
    Long meetings are cut at max_chars; read the file path directly for the rest."""
    for e in _entries():
        if e["id"] == meeting_id.strip():
            text = Path(e["path"]).read_text(encoding="utf-8")
            n = max(1000, int(max_chars))
            return text if len(text) <= n else text[:n] + f"\n\n[cut at {n} characters; full file: {e['path']}]"
    return f"No meeting with id {meeting_id!r}. Call list_meetings for valid ids."


if __name__ == "__main__":
    mcp.run(transport="stdio")
