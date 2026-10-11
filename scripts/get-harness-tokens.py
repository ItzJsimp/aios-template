"""
get-harness-tokens.py - High-speed zero-dependency token telemetry extractor for AIOS.
Extracts exact token metrics:
- Google Antigravity: decodes SQLite protobuf metadata from ~/.gemini/antigravity/conversations/<id>.db
- Anthropic Claude Code: extracts exact usage objects from ~/.claude/projects/*/*.jsonl
Outputs clean JSON to stdout.
"""

import sys
import os
import sqlite3
import json
import glob
from pathlib import Path

def parse_protobuf_metrics(meta_bytes):
    """
    Decodes the generation metrics from Antigravity step metadata protobuf.
    Field 9 contains sub-message with:
      - 5: prompt_tokens (input context window size)
      - 3: total_output_tokens
      - 9: thinking_tokens (CoT reasoning)
      - 10: response_tokens (visible text / tool payload)
      - 2: latency_ms
    """
    if not meta_bytes:
        return None
    
    pos = 0
    f9_bytes = None
    while pos < len(meta_bytes):
        byte = meta_bytes[pos]
        fnum = byte >> 3
        wtype = byte & 0x07
        pos += 1
        if wtype == 0:  # varint
            while pos < len(meta_bytes) and (meta_bytes[pos] & 0x80):
                pos += 1
            if pos < len(meta_bytes):
                pos += 1
        elif wtype == 2:  # length-delimited
            length = 0
            shift = 0
            while pos < len(meta_bytes):
                b = meta_bytes[pos]
                pos += 1
                length |= (b & 0x7F) << shift
                if not (b & 0x80):
                    break
                shift += 7
            chunk = meta_bytes[pos:pos+length]
            pos += length
            if fnum == 9:
                f9_bytes = chunk
                break
        else:
            break
            
    if not f9_bytes:
        return None
        
    spos = 0
    fields = {}
    while spos < len(f9_bytes):
        byte = f9_bytes[spos]
        fnum = byte >> 3
        wtype = byte & 0x07
        spos += 1
        if wtype == 0:
            val = 0
            shift = 0
            while spos < len(f9_bytes):
                b = f9_bytes[spos]
                spos += 1
                val |= (b & 0x7F) << shift
                if not (b & 0x80):
                    break
                shift += 7
            fields[fnum] = val
        elif wtype == 2:
            length = 0
            shift = 0
            while spos < len(f9_bytes):
                b = f9_bytes[spos]
                spos += 1
                length |= (b & 0x7F) << shift
                if not (b & 0x80):
                    break
                shift += 7
            spos += length
        else:
            break
            
    return {
        "input_tokens": fields.get(5, 0),
        "total_output_tokens": fields.get(3, 0),
        "thinking_tokens": fields.get(9, 0),
        "response_tokens": fields.get(10, 0),
        "latency_ms": fields.get(2, 0)
    }

def get_antigravity_data(convo_id=None, latest=False):
    base_dir = os.path.expanduser("~/.gemini/antigravity/conversations")
    if not os.path.exists(base_dir):
        return None
        
    target_db = None
    if convo_id:
        p = os.path.join(base_dir, f"{convo_id}.db")
        if os.path.exists(p):
            target_db = p
        else:
            # A conversation id was supplied but its database is gone: report that
            # instead of silently reading some other conversation's totals. Falling
            # back to "latest" here is how one session's metrics got stamped onto
            # other tasks (the 2026-09-24 / 2026-10-02 duplicate cost tuples).
            return {"harness": "Antigravity", "session_id": convo_id,
                    "error": "conversation database not found"}

    if not target_db:
        # Find latest modified .db file (only reached for id-less CLI queries)
        db_files = glob.glob(os.path.join(base_dir, "*.db"))
        if not db_files:
            return None
        db_files.sort(key=os.path.getmtime, reverse=True)
        target_db = db_files[0]
        
    session_id = Path(target_db).stem
    try:
        conn = sqlite3.connect(f"file:{target_db}?mode=ro", uri=True)
        cursor = conn.cursor()
        cursor.execute("SELECT idx, metadata FROM steps WHERE metadata IS NOT NULL ORDER BY idx ASC")
        rows = cursor.fetchall()
    except Exception as e:
        return {"harness": "Antigravity", "error": str(e), "session_id": session_id}
        
    steps_metrics = []
    for idx, meta in rows:
        m = parse_protobuf_metrics(meta)
        if m:
            m["step_index"] = idx
            steps_metrics.append(m)
            
    latest_step = steps_metrics[-1] if steps_metrics else {
        "input_tokens": 0, "total_output_tokens": 0, "thinking_tokens": 0, "response_tokens": 0, "latency_ms": 0, "step_index": 0
    }

    peak_context = max([s["input_tokens"] for s in steps_metrics]) if steps_metrics else 0
    total_output = sum([s["total_output_tokens"] for s in steps_metrics])
    total_thinking = sum([s["thinking_tokens"] for s in steps_metrics])
    total_response = sum([s["response_tokens"] for s in steps_metrics])
    total_latency_ms = sum([s["latency_ms"] for s in steps_metrics])

    return {
        "harness": "Antigravity",
        "session_id": session_id,
        "db_path": target_db,
        "step_count": len(rows),
        "active_context_tokens": latest_step["input_tokens"],
        "peak_context_tokens": peak_context,
        "total_output_tokens": total_output,
        "total_thinking_tokens": total_thinking,
        "total_response_tokens": total_response,
        "total_latency_ms": total_latency_ms,
        "ai_execution_seconds": round(total_latency_ms / 1000.0, 1),
        "input_tokens": peak_context,
        "output_tokens": total_output,
        "cost_usd": compute_cost_usd(
            # Antigravity conversations carry a Gemini-family model; exact name is not
            # in the SQLite metadata, so pricing keys off the gemini row.
            "gemini",
            input_tokens=peak_context,
            cache_read_tokens=0,
            cache_write_tokens=0,
            output_tokens=total_output,
        ),
        "latest_step": latest_step,
        "steps_with_metrics": len(steps_metrics)
    }

def get_claude_data(session_id=None, latest=False):
    projects_dir = os.path.expanduser("~/.claude/projects")
    if not os.path.exists(projects_dir):
        return None
        
    jsonl_files = glob.glob(os.path.join(projects_dir, "**", "*.jsonl"), recursive=True)
    jsonl_files = [f for f in jsonl_files if not os.path.basename(f).startswith("agent-")]
    if not jsonl_files:
        return None
        
    target_file = None
    if session_id:
        for f in jsonl_files:
            if Path(f).stem == session_id:
                target_file = f
                break
        if not target_file:
            # Session-scoped lookup must never degrade to "latest transcript":
            # that silently reports ANOTHER session's cumulative tokens/cost as if
            # they belonged to this one (the cross-attributed duplicate tuples).
            return {"harness": "Claude", "session_id": session_id,
                    "error": "session transcript not found"}

    if not target_file:
        jsonl_files.sort(key=os.path.getmtime, reverse=True)
        target_file = jsonl_files[0]
        
    sid = Path(target_file).stem
    seen_requests = {}
    user_prompts = 0
    latest_model = None
    # ponytail: naive per-turn latency proxy (gap before each assistant entry), capped to
    # avoid counting long human-idle gaps as AI time. Upgrade to real request duration if
    # the harness ever emits one directly.
    AI_LATENCY_CAP_SEC = 120.0
    ai_execution_seconds = 0.0
    prev_ts = None

    try:
        with open(target_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except Exception:
                    continue

                if entry.get("type") == "user":
                    user_prompts += 1

                ts_raw = entry.get("timestamp")
                cur_ts = None
                if ts_raw:
                    try:
                        cur_ts = __import__("datetime").datetime.fromisoformat(ts_raw.replace("Z", "+00:00"))
                    except Exception:
                        cur_ts = None

                if entry.get("type") == "assistant" and cur_ts and prev_ts:
                    delta = (cur_ts - prev_ts).total_seconds()
                    if delta > 0:
                        ai_execution_seconds += min(delta, AI_LATENCY_CAP_SEC)

                if cur_ts:
                    prev_ts = cur_ts

                req_id = entry.get("requestId") or entry.get("uuid") or entry.get("id")
                usage = None
                msg = entry.get("message") if isinstance(entry.get("message"), dict) else None
                if "usage" in entry:
                    usage = entry["usage"]
                elif msg and "usage" in msg:
                    usage = msg["usage"]
                if msg and msg.get("model"):
                    latest_model = msg.get("model")

                if usage and req_id:
                    seen_requests[req_id] = usage
    except Exception as e:
        return {"harness": "Claude", "error": str(e), "session_id": sid}
        
    uncached = 0
    cache_read = 0
    cache_write = 0
    output_tokens = 0
    thinking_tokens = 0
    latest_usage = None
    
    for u in seen_requests.values():
        latest_usage = u
        c_read = u.get("cache_read_input_tokens", 0)
        c_write = u.get("cache_creation_input_tokens", 0)
        u_in = u.get("input_tokens", 0)
        out = u.get("output_tokens", 0)
        th = 0
        if "output_tokens_details" in u and isinstance(u["output_tokens_details"], dict):
            th = u["output_tokens_details"].get("thinking_tokens", 0)
        elif "thinking_tokens" in u:
            th = u.get("thinking_tokens", 0)
            
        cache_read += c_read
        cache_write += c_write
        uncached += u_in
        output_tokens += out
        thinking_tokens += th
        
    total_prompt = uncached + cache_read + cache_write
    hit_rate = round((cache_read / total_prompt * 100), 1) if total_prompt > 0 else 0.0
    
    # Active context tokens in Claude is cache_read + uncached of the latest turn
    active_context = 0
    if latest_usage:
        active_context = (
            latest_usage.get("cache_read_input_tokens", 0)
            + latest_usage.get("cache_creation_input_tokens", 0)
            + latest_usage.get("input_tokens", 0)
        )
        
    return {
        "harness": "Claude",
        "session_id": sid,
        "log_path": target_file,
        "model": latest_model or "unknown",
        "user_prompts": user_prompts,
        "active_context_tokens": active_context,
        "total_prompt_tokens": total_prompt,
        "cache_read_tokens": cache_read,
        "cache_write_tokens": cache_write,
        "uncached_tokens": uncached,
        "output_tokens": output_tokens,
        "thinking_tokens": thinking_tokens,
        "input_tokens": uncached + cache_write,
        "cache_hit_rate_pct": hit_rate,
        "request_count": len(seen_requests),
        "ai_execution_seconds": round(ai_execution_seconds, 1),
        "cost_usd": compute_cost_usd(
            latest_model or "unknown",
            input_tokens=uncached,
            cache_read_tokens=cache_read,
            cache_write_tokens=cache_write,
            output_tokens=output_tokens,
        )
    }

# Effective Compute Unit weights per wiki/research/2026-09-13-token-economics-multi-harness-orchestration.md
# ECU = alpha*uncached_in + beta*cached_in + gamma*(output+thinking); a turn-60 session (~5M cached
# reads + 60 turns of output) empirically exhausts a Claude Pro 5h rolling window at ~1,000,000 ECU.
ECU_ALPHA = 1.0
ECU_BETA = 0.10
ECU_GAMMA = 5.0
CLAUDE_5H_ECU_BUDGET = 1_000_000

# Model pricing (USD per million tokens): {input, cached_read, cached_write, output}.
# Default row covers unknown models so cost-per-task stays computable (flagged approximate).
MODEL_PRICING = {
    "default": {"input": 1.0, "cached_read": 0.1, "cached_write": 1.25, "output": 5.0},
    "claude-sonnet": {"input": 3.0, "cached_read": 0.3, "cached_write": 3.75, "output": 15.0},
    "claude-opus": {"input": 15.0, "cached_read": 1.5, "cached_write": 18.75, "output": 75.0},
    "claude-haiku": {"input": 1.0, "cached_read": 0.1, "cached_write": 1.25, "output": 5.0},
    "gemini": {"input": 0.15, "cached_read": 0.015, "cached_write": 0.15, "output": 0.6},
}

def _pricing_for(model):
    m = (model or "").lower()
    for key, table in MODEL_PRICING.items():
        if key != "default" and key in m:
            return table
    return MODEL_PRICING["default"]

def compute_cost_usd(model, input_tokens=0, cache_read_tokens=0, cache_write_tokens=0, output_tokens=0):
    """Cost estimate in USD from token counts and the per-model pricing table."""
    p = _pricing_for(model)
    mtok = 1_000_000.0
    return round(
        (input_tokens * p["input"]
         + cache_read_tokens * p["cached_read"]
         + cache_write_tokens * p["cached_write"]
         + output_tokens * p["output"]) / mtok,
        4
    )

def compute_ecu(uncached, cached, output, thinking):
    return ECU_ALPHA * uncached + ECU_BETA * cached + ECU_GAMMA * (output + thinking)

def get_claude_rolling_window(hours=5.0):
    """
    Scans every Claude Code JSONL log (all sessions, all projects) for requests inside the
    trailing N-hour window and returns aggregate ECU load against the calibrated budget.
    """
    projects_dir = os.path.expanduser("~/.claude/projects")
    if not os.path.exists(projects_dir):
        return None

    jsonl_files = glob.glob(os.path.join(projects_dir, "**", "*.jsonl"), recursive=True)
    jsonl_files = [f for f in jsonl_files if not os.path.basename(f).startswith("agent-")]
    if not jsonl_files:
        return None

    from datetime import datetime, timezone, timedelta
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)

    seen_requests = {}
    seen_uuids = set()
    oldest_ts = None
    for path in jsonl_files:
        try:
            with open(path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry = json.loads(line)
                    except Exception:
                        continue

                    ts = entry.get("timestamp")
                    if not ts:
                        continue
                    try:
                        entry_time = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                    except Exception:
                        continue
                    if entry_time < cutoff:
                        continue

                    req_id = entry.get("requestId") or entry.get("uuid") or entry.get("id")
                    usage = None
                    if "usage" in entry:
                        usage = entry["usage"]
                    elif "message" in entry and isinstance(entry["message"], dict) and "usage" in entry["message"]:
                        usage = entry["message"]["usage"]
                    if usage and req_id:
                        seen_requests[req_id] = usage
                        if entry.get("uuid"):
                            seen_uuids.add(entry["uuid"])
                        if oldest_ts is None or entry_time < oldest_ts:
                            oldest_ts = entry_time
        except Exception:
            continue

    uncached = cache_read = cache_write = output_tokens = thinking_tokens = 0
    for u in seen_requests.values():
        cache_read += u.get("cache_read_input_tokens", 0)
        cache_write += u.get("cache_creation_input_tokens", 0)
        uncached += u.get("input_tokens", 0)
        output_tokens += u.get("output_tokens", 0)
        if "output_tokens_details" in u and isinstance(u["output_tokens_details"], dict):
            thinking_tokens += u["output_tokens_details"].get("thinking_tokens", 0)
        else:
            thinking_tokens += u.get("thinking_tokens", 0)

    # Source 2: token-dashboard.db (ingested by scripts/Setup-TokenDashboard.ps1's
    # scheduled scanner). Backfills any in-window requests absent from the JSONL
    # logs (rotated or pruned session files), de-duplicated by message uuid.
    db_count = 0
    db_path = os.path.expanduser("~/.claude/token-dashboard.db")
    if os.path.exists(db_path):
        try:
            import sqlite3
            cutoff_str = cutoff.strftime("%Y-%m-%dT%H:%M:%S.") + f"{cutoff.microsecond // 1000:03d}Z"
            con = sqlite3.connect(f"file:{db_path.replace(os.sep, '/')}?mode=ro", uri=True)
            try:
                rows = con.execute(
                    "SELECT uuid, timestamp, input_tokens, output_tokens, cache_read_tokens,"
                    " cache_create_5m_tokens, cache_create_1h_tokens FROM messages"
                    " WHERE type='assistant' AND timestamp >= ?",
                    (cutoff_str,)).fetchall()
            finally:
                con.close()
            for uuid, ts, tin, tout, tread, tc5, tc1 in rows:
                if uuid in seen_uuids:
                    continue
                seen_uuids.add(uuid)
                try:
                    row_time = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                except Exception:
                    continue
                if row_time < cutoff:
                    continue
                uncached += tin or 0
                cache_read += tread or 0
                cache_write += (tc5 or 0) + (tc1 or 0)
                output_tokens += tout or 0
                db_count += 1
                if oldest_ts is None or row_time < oldest_ts:
                    oldest_ts = row_time
        except Exception:
            pass

    # ECU: gamma applies to output tokens once. Anthropic's usage.output_tokens
    # already includes thinking tokens, so adding thinking_tokens again here
    # would double count them at the output weight.
    ecu = compute_ecu(uncached, cache_read + cache_write, output_tokens, 0)

    return {
        "harness": "Claude",
        "window_hours": hours,
        "request_count": len(seen_requests),
        "db_request_count": db_count,
        "oldest_ts": oldest_ts.isoformat() if oldest_ts else None,
        "uncached_tokens": uncached,
        "cache_read_tokens": cache_read,
        "cache_write_tokens": cache_write,
        "output_tokens": output_tokens,
        "thinking_tokens": thinking_tokens,
        "ecu": round(ecu),
        "ecu_budget": CLAUDE_5H_ECU_BUDGET,
        "pct_of_budget": round((ecu / CLAUDE_5H_ECU_BUDGET) * 100, 1)
    }

def detect_harness():
    # 1. Antigravity env markers
    if os.environ.get("ANTIGRAVITY_AGENT") or os.environ.get("ANTIGRAVITY_CONVERSATION_ID"):
        return "Antigravity"
    # 2. Claude Code env markers
    if os.environ.get("CLAUDE_PROJECT_DIR") or os.environ.get("CLAUDE_SESSION_ID"):
        return "Claude"
    return "Auto"

def selftest() -> int:
    h = detect_harness()
    assert h in ("Antigravity", "Claude", "Auto"), f"Unexpected harness: {h}"
    print("[PASS] get-harness-tokens selftest: pass")
    return 0


if __name__ == "__main__":
    if "--self-test" in sys.argv or "--selftest" in sys.argv or "--check" in sys.argv:
        sys.exit(selftest())
    import argparse
    parser = argparse.ArgumentParser(description="AIOS Harness Token Extractor")
    parser.add_argument("--harness", choices=["Antigravity", "Claude", "Auto", "All"], default="Auto")
    parser.add_argument("--conversation-id", default=None)
    parser.add_argument("--session-id", default=None)
    parser.add_argument("--active-only", action="store_true")
    parser.add_argument("--quota-velocity", action="store_true", help="Rolling N-hour ECU quota load across all Claude Code sessions")
    parser.add_argument("--window-hours", type=float, default=5.0)
    args = parser.parse_args()

    if args.quota_velocity:
        print(json.dumps(get_claude_rolling_window(hours=args.window_hours), indent=2))
        sys.exit(0)

    target_harness = args.harness
    if target_harness == "Auto":
        detected = detect_harness()
        if detected != "Auto":
            target_harness = detected
        else:
            # ponytail: neither harness's env markers are visible to this process (common when
            # invoked from a plain subprocess shell instead of a harness-injected hook context).
            # Guessing a fixed harness here silently reports the WRONG session's tokens; pick
            # whichever data source was touched most recently instead of hardcoding one.
            claude_dir = os.path.expanduser("~/.claude/projects")
            claude_files = glob.glob(os.path.join(claude_dir, "**", "*.jsonl"), recursive=True) if os.path.exists(claude_dir) else []
            claude_mtime = max((os.path.getmtime(f) for f in claude_files), default=0)
            agy_dir = os.path.expanduser("~/.gemini/antigravity/conversations")
            agy_files = glob.glob(os.path.join(agy_dir, "*.db")) if os.path.exists(agy_dir) else []
            agy_mtime = max((os.path.getmtime(f) for f in agy_files), default=0)
            target_harness = "Claude" if claude_mtime >= agy_mtime else "Antigravity"
        
    convo_id = args.conversation_id or os.environ.get("ANTIGRAVITY_CONVERSATION_ID")
    claude_id = args.session_id
    
    results = {}
    if target_harness in ("Antigravity", "All"):
        results["antigravity"] = get_antigravity_data(convo_id=convo_id)
    if target_harness in ("Claude", "All"):
        results["claude"] = get_claude_data(session_id=claude_id)
        
    if args.active_only:
        # Just return the single active context number for quick footers/diagnostics
        active_tokens = 0
        if target_harness == "Antigravity" and results.get("antigravity"):
            active_tokens = results["antigravity"].get("active_context_tokens", 0)
        elif target_harness == "Claude" and results.get("claude"):
            active_tokens = results["claude"].get("active_context_tokens", 0)
        print(active_tokens)
    else:
        print(json.dumps(results, indent=2))
