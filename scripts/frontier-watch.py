"""
frontier-watch.py - weekly frontier feed: max 3 adoptable tactics, each diffed against what AIOS already has.

Deterministic, $0, stdlib only. Pulls scripts/frontier-sources.json (Atom/RSS), keeps items from
the last N days, ranks by source weight + tactic-word hits, and for each top item names the
closest existing skill/standard so you see "already covered" vs "gap". Writes
logs/frontier-watch.md. A dead feed is listed, never fatal.

Usage: python scripts/frontier-watch.py [--days 7] [--dry-run] [--self-test]
"""
import argparse
import json
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "logs" / "frontier-watch.md"
UA = {"User-Agent": "Mozilla/5.0 (aios-frontier-watch)"}
STOP = set("the a an and or of to for in on with is are this that new how why what your you from it its at by be as".split())


def words(t):
    return {w for w in re.findall(r"[a-z][a-z0-9-]{3,}", t.lower()) if w not in STOP}


def parse_date(s):
    if not s:
        return None
    try:
        d = datetime.fromisoformat(s.strip().replace("Z", "+00:00"))
    except ValueError:
        try:
            d = parsedate_to_datetime(s)
        except Exception:
            return None
    return d if d.tzinfo else d.replace(tzinfo=timezone.utc)


def parse_feed(xml_bytes):
    """Yield (title, link, date, summary) from Atom or RSS."""
    root = ET.fromstring(xml_bytes)
    for el in root.iter():
        tag = el.tag.split("}")[-1]
        if tag not in ("entry", "item"):
            continue
        g = {c.tag.split("}")[-1]: c for c in el}
        title = (g["title"].text or "").strip() if "title" in g else ""
        link = ""
        if "link" in g:
            link = g["link"].get("href") or (g["link"].text or "")
        date = parse_date(next((g[k].text for k in ("updated", "published", "pubDate") if k in g), None))
        summ = next(((g[k].text or "") for k in ("summary", "description", "content") if k in g), "")
        yield title, link.strip(), date, re.sub(r"<[^>]+>", " ", summ)[:600]


def local_corpus():
    """name -> keyword set for every skill and standard AIOS already has."""
    corpus = {}
    for sk in (ROOT / ".agents" / "skills").glob("*/SKILL.md"):
        head = sk.read_text(encoding="utf-8", errors="ignore")[:900]
        corpus[f"skill:{sk.parent.name}"] = words(sk.parent.name.replace("-", " ") + " " + head)
    for st in (ROOT / "standards").glob("*.md"):
        corpus[f"standard:{st.stem}"] = words(st.stem.replace("-", " ") + " " + st.read_text(encoding="utf-8", errors="ignore")[:900])
    return corpus


def closest(item_words, corpus):
    best, score = None, 0.0
    for name, kw in corpus.items():
        if not kw:
            continue
        s = len(item_words & kw) / (len(item_words) ** 0.5 * len(kw) ** 0.5 or 1)
        if s > score:
            best, score = name, s
    return best, score


def rank(items, tactic_words, corpus):
    out = []
    for it in items:
        text = f"{it['title']} {it['summary']}".lower()
        hits = sorted({w for w in tactic_words if w in text})
        if not hits:
            continue
        near, sim = closest(words(it["title"] + " " + it["summary"]), corpus)
        covered = sim >= 0.12
        out.append({**it, "hits": hits, "near": near, "sim": round(sim, 2), "covered": covered,
                    "score": it["weight"] * 2 + len(hits) - (3 if covered else 0)})
    picked, seen = [], set()
    for it in sorted(out, key=lambda x: -x["score"]):  # one item per source so one noisy feed cannot take all 3
        if it["source"] not in seen:
            seen.add(it["source"])
            picked.append(it)
    return picked[:3]


def fetch_all(cfg, days):
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    items, dead = [], []
    for src in cfg["sources"]:
        try:
            req = urllib.request.Request(src["url"], headers=UA)
            with urllib.request.urlopen(req, timeout=25) as r:
                data = r.read()
            for title, link, date, summ in parse_feed(data):
                if date and date >= cutoff and title:
                    items.append({"source": src["name"], "weight": src.get("weight", 1), "title": title,
                                  "link": link, "date": date.date().isoformat(), "summary": summ})
        except Exception as ex:
            dead.append(f"{src['name']}: {type(ex).__name__}")
    return items, dead


def self_test():
    atom = b'<feed xmlns="http://www.w3.org/2005/Atom"><entry><title>Subagent hooks land</title><link href="http://x/1"/><updated>2999-01-01T00:00:00Z</updated><summary>new hook for subagent</summary></entry></feed>'
    rss = b'<rss><channel><item><title>Cache tips</title><link>http://x/2</link><pubDate>Mon, 01 Jan 2999 00:00:00 GMT</pubDate></item></channel></rss>'
    assert next(parse_feed(atom))[0] == "Subagent hooks land" and next(parse_feed(rss))[2].year == 2999
    corpus = {"skill:subagent-hooks": words("subagent hooks"), "skill:other": words("pricing tiers")}
    cfg_items = [{"source": "s", "weight": 2, "title": "Subagent hooks land", "link": "l", "date": "d", "summary": "hook subagent"},
                 {"source": "s", "weight": 2, "title": "Gardening", "link": "l", "date": "d", "summary": "plants"}]
    r = rank(cfg_items, ["hook", "subagent"], corpus)
    assert len(r) == 1 and r[0]["covered"] and r[0]["near"] == "skill:subagent-hooks"
    print("[PASS] frontier-watch selftest")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        return self_test()
    cfg = json.loads((ROOT / "scripts" / "frontier-sources.json").read_text(encoding="utf-8"))
    items, dead = fetch_all(cfg, a.days)
    top = rank(items, cfg["tactic_words"], local_corpus())
    lines = [f"# Frontier watch, week ending {datetime.now(timezone.utc).date().isoformat()}", "",
             f"{len(items)} items from {len(cfg['sources']) - len(dead)}/{len(cfg['sources'])} sources; top {len(top)} adoptable:", ""]
    for i, t in enumerate(top, 1):
        status = f"already close to `{t['near']}` (similarity {t['sim']}): check before building" if t["covered"] \
            else f"no close match (nearest `{t['near']}` at {t['sim']}): likely a gap"
        lines += [f"{i}. **[{t['title']}]({t['link']})** ({t['source']}, {t['date']})",
                  f"   - Says: {' '.join(t['summary'].split())[:220]}", f"   - Tactic words: {', '.join(t['hits'])}", f"   - AIOS diff: {status}"]
    if not top:
        lines.append("Nothing adoptable this week.")
    if dead:
        lines += ["", "Dead feeds (fix or drop in `scripts/frontier-sources.json`): " + "; ".join(dead)]
    report = ("\n".join(lines) + "\n").replace(chr(0x2014), " - ")  # ADR-0012: feeds carry em dashes
    if not a.dry_run:
        OUT.write_text(report, encoding="utf-8")
    print(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
