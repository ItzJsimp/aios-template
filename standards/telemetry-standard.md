# Telemetry & Operational Event Standard: {{AIOS_NAME}}

Standard schema and logging rules for recording AI activity in {{AIOS_NAME}}.

## Principles
1. **Append-Only JSONL:** All telemetry logs use newline-delimited JSON (`.jsonl`) for fast appending and corruption resistance.
2. **Zero Overhead:** Logging happens inline during execution or closeout rituals.
3. **Privacy First:** Only log task slugs, skill names, and performance metrics. Never log private credentials or sensitive personal text.
