"""
score-operator.py - weekly AI-native operator scorecard (grades {{OPERATOR_NAME}}, not the AI).

Deterministic metrics over the last N days of Claude Code transcripts; token/cost
numbers come from get-harness-tokens.py (imported, not forked). Appends one JSON
line to logs/operator-scorecard.jsonl and writes logs/operator-scorecard-report.md
(lowest pillar + one experiment). --judge adds ONE local-LLM critique of 5 prompts
(Ollama gpt-oss:20b, free and private); it never changes the scores.

Usage: python scripts/score-operator.py [--days 7] [--judge] [--dry-run] [--self-test]
"""
import argparse
import glob
import importlib.util
import json
import os
import re
import statistics
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOG = ROOT / "logs" / "operator-scorecard.jsonl"
REPORT = ROOT / "logs" / "operator-scorecard-report.md"

CORRECTION = re.compile(r"^\s*(no[,. !]|nope|wrong|that'?s not|i said|not what i|stop\b|why did you|undo|revert)", re.I)
VERIFY = re.compile(r"\b(verify|test|diff|show me|prove|check|screenshot|run it|did it work|confirm)\b", re.I)
CONSTRAINT = re.compile(r"([A-Za-z]:\\|\./|\.md\b|\.py\b|\.ps1\b|\.tsx?\b|\bdon'?t\b|\bnever\b|\bonly\b|\bmust\b|\bdone when\b)", re.I)
PILLARS = ["prompting", "oversight", "delegation", "tool_adoption", "context_hygiene", "cost_efficiency"]

# Experiments keyed by pillar; the report names exactly one (the lowest).
EXPERIMENTS = {
    "prompting": "Every prompt this week names a file or path and one constraint (Don't / Done when).",
    "oversight": "Ask for proof (diff, test output, screenshot) before accepting 'done' in every session.",
    "delegation": "Hand any 20+ tool-call job to the executor subagent with a written brief.",
    "tool_adoption": "Invoke 3 skills or MCP tools you have not used in the last 30 days.",
    "context_hygiene": "Open a fresh chat at every phase boundary; none past 50 prompts or 400K context.",
    "cost_efficiency": "Keep sessions on one topic so the prompt cache stays warm (target 90%+ hit rate).",
}

# Actionable tips per pillar, shown (max 3, weakest first) whenever a pillar scores under ADVICE_BELOW.
ADVICE = {
    "prompting": ["Open each request with the file or path it touches.", "End it with one 'Done when' check so the agent can verify itself.", "Replace one-word replies ('ok', 'no') with the reason and the next step."],
    "oversight": ["Ask for proof (diff, test output, screenshot) before accepting 'done'.", "Interrupt a long run the moment it drifts instead of correcting afterwards.", "Spot-check one file the agent edited in every session."],
    "delegation": ["Hand any 20+ tool-call job to a subagent with a written brief.", "Send read-only sweeps to the cheapest model.", "Run independent searches in parallel instead of one after another."],
    "tool_adoption": ["Invoke one skill you have not used this month.", "Connect one MCP server that removes a copy-paste step.", "Turn any step you repeat 3 times into a skill or script."],
    "context_hygiene": ["Start a fresh chat at each phase boundary.", "Save a handoff note, then close chats past 50 prompts.", "Keep one topic per chat so context stays small."],
    "cost_efficiency": ["Stay on one topic per chat so the prompt cache stays warm.", "Put long outputs in files, not the chat body.", "Move bulk work to a cheaper model."],
}
ADVICE_BELOW = 75


def load_tokens():
    spec = importlib.util.spec_from_file_location("ght", ROOT / "scripts" / "get-harness-tokens.py")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def clamp(x):
    return max(0, min(100, round(x)))


def human_text(entry):
    """Return the typed prompt text, or None for tool results / meta / sidechain entries."""
    if entry.get("type") != "user" or entry.get("isMeta") or entry.get("isSidechain"):
        return None
    c = (entry.get("message") or {}).get("content")
    if isinstance(c, list):
        parts = [b.get("text", "") for b in c if isinstance(b, dict) and b.get("type") == "text"]
        c = "\n".join(parts) if parts else None
    if not isinstance(c, str):
        return None
    c = re.sub(r"<pasted_content[^>]*>.*?</pasted_content[^>]*>", "", c, flags=re.S).strip()
    if not c or c.startswith(("<command-", "<local-command", "[Request interrupted", "Caveat:")):
        return None
    return c


def scan_session(path, cutoff):
    """One pass: behavioural counters for a single transcript."""
    s = {"id": Path(path).stem, "prompts": [], "tool_calls": 0, "agent_calls": 0,
         "tools": set(), "skills": set(), "interrupts": 0, "denials": 0}
    with open(path, encoding="utf-8") as f:
        for line in f:
            try:
                e = json.loads(line)
            except Exception:
                continue
            ts = e.get("timestamp")
            if ts:
                try:
                    if datetime.fromisoformat(ts.replace("Z", "+00:00")) < cutoff:
                        continue
                except Exception:
                    pass
            t = human_text(e)
            if t:
                s["prompts"].append(t)
            content = (e.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            for b in content:
                if not isinstance(b, dict):
                    continue
                if b.get("type") == "tool_use" and e.get("type") == "assistant":
                    name = b.get("name", "")
                    s["tool_calls"] += 1
                    if name in ("Agent", "Task"):
                        s["agent_calls"] += 1
                    elif name == "Skill":
                        s["skills"].add((b.get("input") or {}).get("skill", "?"))
                    elif name.startswith("mcp__"):
                        s["tools"].add(name)
                elif b.get("type") == "tool_result":
                    txt = json.dumps(b.get("content", ""))[:300]
                    if "doesn't want to proceed" in txt or "was rejected" in txt:
                        s["denials"] += 1
                elif b.get("type") == "text" and "[Request interrupted" in b.get("text", ""):
                    s["interrupts"] += 1
    return s


def score(sessions, tok):
    """sessions: list of (scan dict, token dict|None). Returns (scores, evidence, raw)."""
    live = [(s, t) for s, t in sessions if s["prompts"]]
    if not live:
        return None
    prompts = [(p, s["id"]) for s, _ in live for p in s["prompts"]]
    n = len(prompts)

    # prompting: no tiny prompts, no corrections, specific (path/constraint) prompts
    tiny = sum(len(p) < 15 for p, _ in prompts) / n
    corr = sum(bool(CORRECTION.match(p)) for p, _ in prompts) / n
    spec = sum(bool(CONSTRAINT.search(p)) for p, _ in prompts) / n
    per_sess = {}
    for p, sid in prompts:
        d = per_sess.setdefault(sid, [0, 0])
        d[0] += bool(CORRECTION.match(p)) or len(p) < 15
        d[1] += 1
    worst_prompt = max(per_sess, key=lambda k: per_sess[k][0] / per_sess[k][1])
    prompting = clamp(40 + spec * 80 - corr * 150 - tiny * 60)

    # oversight: sessions where {{OPERATOR_NAME}} asked for proof, interrupted, or denied a tool call
    over = [s for s, _ in live if any(VERIFY.search(p) for p in s["prompts"]) or s["interrupts"] or s["denials"]]
    oversight = clamp(len(over) / len(live) * 100)
    unreviewed = [s for s, _ in live if s not in over and s["tool_calls"] > 20]
    ev_over = max(unreviewed, key=lambda s: s["tool_calls"])["id"] if unreviewed else live[0][0]["id"]

    # delegation: Agent calls per tool call (3% = full marks); long sessions with none cost 1 point each
    tc = sum(s["tool_calls"] for s, _ in live) or 1
    ac = sum(s["agent_calls"] for s, _ in live)
    long_none = [s for s, _ in live if s["tool_calls"] > 40 and not s["agent_calls"]]
    delegation = clamp(ac / tc / 0.03 * 100 - len(long_none))
    ev_deleg = max(long_none, key=lambda s: s["tool_calls"])["id"] if long_none else live[0][0]["id"]

    # tool adoption: distinct skills (target 8) + distinct MCP tools (target 6)
    skills = set().union(*(s["skills"] for s, _ in live))
    mcps = set().union(*(s["tools"] for s, _ in live))
    adoption = clamp(min(len(skills) / 8, 1) * 60 + min(len(mcps) / 6, 1) * 40)
    ev_adopt = min(live, key=lambda x: len(x[0]["skills"]) + len(x[0]["tools"]))[0]["id"]

    # context hygiene: sessions under 50 prompts and 400K peak active context
    toks = [(s, t) for s, t in live if t and not t.get("error")]
    def heavy(s, t):
        return len(s["prompts"]) > 50 or t.get("active_context_tokens", 0) > 400_000
    hyg_bad = [(s, t) for s, t in toks if heavy(s, t)]
    hygiene = clamp(100 - len(hyg_bad) / max(len(toks), 1) * 100)
    ev_hyg = max(toks, key=lambda x: x[1].get("active_context_tokens", 0))[0]["id"] if toks else live[0][0]["id"]

    # cost efficiency: cache hit rate (90% = full) dragged by median API-equivalent cost per prompt over $2
    hit = statistics.mean(t.get("cache_hit_rate_pct", 0) for _, t in toks) if toks else 0
    cpp = [t["cost_usd"] / max(len(s["prompts"]), 1) for s, t in toks]
    med_cpp = statistics.median(cpp) if cpp else 0
    cost_eff = clamp(min(hit / 90, 1) * 100 - max(0, med_cpp - 2.0) * 20)
    ev_cost = max(toks, key=lambda x: x[1]["cost_usd"])[0]["id"] if toks else live[0][0]["id"]

    scores = dict(zip(PILLARS, [prompting, oversight, delegation, adoption, hygiene, cost_eff]))
    evidence = dict(zip(PILLARS, [worst_prompt, ev_over, ev_deleg, ev_adopt, ev_hyg, ev_cost]))
    raw = {"sessions": len(live), "prompts": n, "tiny_pct": round(tiny * 100, 1),
           "correction_pct": round(corr * 100, 1), "specific_pct": round(spec * 100, 1),
           "agent_calls": ac, "tool_calls": tc, "skills_used": len(skills), "mcp_tools_used": len(mcps),
           "avg_cache_hit_pct": round(hit, 1), "median_cost_per_prompt": round(med_cpp, 3),
           "week_cost_usd": round(sum(t["cost_usd"] for _, t in toks), 2)}
    return scores, evidence, raw


def redact(t, limit=300):
    """Strip identifying detail before text leaves the machine (free OpenRouter models may log prompts)."""
    t = re.sub(r"[\w.+-]+@[\w-]+\.[\w.]+", "<email>", t)
    t = re.sub(r"https?://\S+", "<url>", t)
    t = re.sub(r"[A-Za-z]:\\[^\s\"']+", "<path>", t)
    t = re.sub(r"\b(sk|pk|ghp|xox[a-z])[-_][\w-]{8,}", "<key>", t)
    t = re.sub(r"\$\s?\d[\d,.]*[kKmM]?|\b\d{4,}\b", "<num>", t)
    return t[:limit]


def judge_openrouter(ask):
    import urllib.request
    key = os.environ.get("OPENROUTER_API_KEY")
    if not key:
        return None
    req = urllib.request.Request("https://openrouter.ai/api/v1/chat/completions", method="POST",
                                 data=json.dumps({"model": "openrouter/free", "messages": [{"role": "user", "content": ask}]}).encode(),
                                 headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            out = json.load(r)["choices"][0]["message"]["content"].strip()
        return f"(openrouter/free, redacted excerpts) {out}" if out else None
    except Exception as ex:
        print(f"[judge] openrouter failed: {ex}", file=sys.stderr)
        return None


def judge(prompts):
    """One free local-LLM critique over 5 prompts. Returns text or None (never raises)."""
    import urllib.request
    pick = sorted(prompts, key=len, reverse=True)[:5]
    body = "\n\n".join(f"[{i+1}] {p[:600]}" for i, p in enumerate(pick))
    ask = ("You grade how well an operator writes prompts for coding agents. For each numbered prompt give one "
           "line: what was unclear or missing, and a one-line rewrite hint. No praise, max 120 words total.\n\n" + body)
    for model in ("gpt-oss:20b", "gemma3:4b"):  # big model first, small one if it fails to load
        req = urllib.request.Request("http://localhost:11434/api/generate", method="POST",
                                     data=json.dumps({"model": model, "prompt": ask, "stream": False}).encode(),
                                     headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                out = json.load(r).get("response", "").strip()
            if out:
                return f"({model}) {out}"
        except Exception as ex:  # ponytail: no OpenRouter fallback yet; add redacted-excerpt fallback if Ollama is often down
            print(f"[judge] {model} failed: {ex}", file=sys.stderr)
    # Local models failed: ship only redacted 300-char excerpts to OpenRouter's free router.
    red = "\n\n".join(f"[{i+1}] {redact(p)}" for i, p in enumerate(pick))
    return judge_openrouter(ask.split("\n\n", 1)[0] + "\n\n" + red)


def previous_row():
    if not LOG.exists():
        return None
    rows = [json.loads(l) for l in LOG.read_text(encoding="utf-8").splitlines() if l.strip()]
    return rows[-1] if rows else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--judge", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        return self_test()

    cutoff = datetime.now(timezone.utc) - timedelta(days=a.days)
    tok = load_tokens()
    files = [f for f in glob.glob(os.path.expanduser("~/.claude/projects/*/*.jsonl"))
             if not os.path.basename(f).startswith("agent-")
             and datetime.fromtimestamp(os.path.getmtime(f), timezone.utc) >= cutoff]
    sessions = []
    for f in files:
        s = scan_session(f, cutoff)
        t = tok.get_claude_data(session_id=s["id"]) if s["prompts"] else None
        sessions.append((s, t))
    res = score(sessions, tok)
    if not res:
        print("no sessions with prompts in window")
        return 1
    scores, evidence, raw = res
    overall = round(sum(scores.values()) / len(scores))
    prev = previous_row()
    delta = {k: scores[k] - prev["scores"][k] for k in PILLARS} if prev else None
    row = {"week_ending": datetime.now(timezone.utc).date().isoformat(), "days": a.days,
           "scores": scores, "overall": overall, "delta": delta,
           "overall_delta": overall - prev["overall"] if prev else None,
           "evidence_session": evidence, "raw": raw}
    low = min(scores, key=scores.get)
    advice = [{"pillar": k, "score": scores[k], "tips": ADVICE[k][:3]}
              for k in sorted(scores, key=scores.get) if scores[k] < ADVICE_BELOW][:3]
    row["advice"] = advice
    critique = judge([p for s, _ in sessions for p in s["prompts"]]) if a.judge else None

    lines = [f"# Operator scorecard, week ending {row['week_ending']}", "",
             f"**Overall: {overall}/100**" + (f" ({row['overall_delta']:+d} vs last week)" if prev else ""), "",
             "| Pillar | Score | Delta | Evidence session |", "|---|---|---|---|"]
    for k in PILLARS:
        lines.append(f"| {k} | {scores[k]} | {delta[k]:+d} | `{evidence[k][:8]}` |" if delta else f"| {k} | {scores[k]} | n/a | `{evidence[k][:8]}` |")
    lines += ["", f"**Lowest pillar: {low} ({scores[low]})**", f"**Experiment for next week:** {EXPERIMENTS[low]}", "",
              f"Raw: {json.dumps(raw)}"]
    if advice:
        lines += ["", "## How to raise the score"]
        for a_ in advice:
            lines += [f"**{a_['pillar']} ({a_['score']})**"] + [f"- {t}" for t in a_["tips"]]
    if critique:
        lines += ["", "## Local-LLM prompt critique (advisory, not scored)", critique]
    report = "\n".join(lines) + "\n"
    if a.dry_run:
        print(report)
        return 0
    LOG.parent.mkdir(exist_ok=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps(row) + "\n")
    REPORT.write_text(report, encoding="utf-8")
    print(report)
    return 0


def self_test():
    assert human_text({"type": "user", "message": {"content": "hello there friend"}}) == "hello there friend"
    assert human_text({"type": "user", "message": {"content": [{"type": "tool_result"}]}}) is None
    assert human_text({"type": "user", "isMeta": True, "message": {"content": "x" * 30}}) is None
    assert CORRECTION.match("no, that's wrong") and not CORRECTION.match("note this")
    mk = lambda i, ps, tc, ac: {"id": i, "prompts": ps, "tool_calls": tc, "agent_calls": ac,
                                "tools": {"mcp__a__b"}, "skills": {"x"}, "interrupts": 0, "denials": 0}
    t = {"cost_usd": 1.0, "cache_hit_rate_pct": 95, "active_context_tokens": 100_000}
    good = score([(mk("g", ["Fix {{DATA_DRIVE}}\\a\\b.py, don't touch c " * 2, "verify with a test"], 50, 5), t)], None)
    bad = score([(mk("b", ["no", "wrong, that's not it", "ok"], 80, 0), {**t, "active_context_tokens": 900_000})], None)
    assert good[0]["prompting"] > bad[0]["prompting"] and good[0]["delegation"] > bad[0]["delegation"]
    assert bad[0]["context_hygiene"] == 0
    r = redact("mail a@b.com at {{DATA_DRIVE}}\\x\\y.md owes $1,200 key sk-abcdef123456 http://a.b/c 123456")
    assert not any(k in r for k in ("a@b.com", "{{DATA_DRIVE}}\\", "1,200", "sk-abc", "http", "123456")), r
    print("[PASS] score-operator selftest")
    return 0


if __name__ == "__main__":
    sys.exit(main())
