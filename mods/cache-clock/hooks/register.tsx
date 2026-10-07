import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

// ponytail: fixed 1h TTL (subscription plan); add a userConfig option if you ever use 5m
const TTL_MS = 60 * 60 * 1000
const NUDGE_AT = 300_000
const CELLS = 30
const lastAt = atom({ plugin: 'cache-clock', key: 'lastAt' } as const, null)
const now = atom({ plugin: 'cache-clock', key: 'now' } as const, 0)
const tokens = atom({ plugin: 'cache-clock', key: 'tokens' } as const, 0)
const hit = atom({ plugin: 'cache-clock', key: 'hit' } as const, null)

const HEX: Record<string, string> = { green: '#30d158', yellow: '#ffd60a', red: '#ff453a', gray: '#8e8e93' }

const fmt = (ms: number) => {
  const s = Math.max(0, Math.floor(ms / 1000))
  const m = Math.floor(s / 60)
  return m >= 5 ? `${m}m left` : `${m}:${String(s % 60).padStart(2, '0')} left`
}

// green 60-30m, yellow 30-10m, red under 10m
const colorFor = (left: number | null) =>
  left === null || left <= 0 ? 'gray' : left < 10 * 60000 ? 'red' : left < 30 * 60000 ? 'yellow' : 'green'

export const register: Register = on => {
  let nudged = false

  on('session.start', async ($, e, next) => {
    // a fresh or resumed session has no known warm cache until the first reply lands
    await update($, lastAt, () => null)
    $.clock.every(5000, async () => update($, now, () => Date.now()))
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    // an answered main-thread turn made API requests, so the cache clock restarts; subagents have their own prefix
    if (!e.agentId && e.usage) {
      const t = await $.clock.now()
      await update($, lastAt, () => t)
      await update($, now, () => t)
      const u = e.usage
      const total = u.input_tokens + u.cache_read_input_tokens + u.cache_creation_input_tokens
      await update($, hit, () => (total > 0 ? Math.round((u.cache_read_input_tokens / total) * 100) : null))
      const { context } = await $.session.usage()
      const size = context.tokens ?? 0
      await update($, tokens, () => size)
      if (size >= NUDGE_AT && !nudged) {
        nudged = true
        $.ui.toast(`Context ${Math.round(size / 1000)}K: time to write a handoff and start a fresh session`)
      } else if (size < NUDGE_AT) {
        nudged = false
      }
    }
    return next(e)
  })

  // wraps next(e) so the other band mods (quick-replies) still draw under this row
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const rest = await next(e)
    if (e.props.hasSurvey) return rest
    const { Box, Text, Svg } = $.ui.resolve(e)
    const at = await read($, lastAt)
    const n = (await read($, now)) || (await $.clock.now())
    const size = await read($, tokens)
    const pct = await read($, hit)
    const left = at === null ? null : TTL_MS - (n - at)
    const color = colorFor(left)
    const frac = left === null ? 0 : Math.max(0, Math.min(1, left / TTL_MS))
    const value = left === null ? 'no reply yet' : left <= 0 ? 'expired' : fmt(left)

    // desktop, editor, mobile: one vector pill, left-aligned: cache time, context vs the 300K handoff line, hit rate
    // ponytail: fixed 664px layout; no hook seats a node beside the model picker, so it lives in the band above it
    if (e.surface !== 'terminal') {
      const hex = HEX[color]
      const ctxFrac = Math.min(1, size / NUDGE_AT)
      const ctxHex = size >= NUDGE_AT * 0.85 ? HEX.red : size >= NUDGE_AT * 0.6 ? HEX.yellow : HEX.green
      const bar = (x: number, w: number, f: number, fill: string) =>
        `<rect x="${x}" y="12" width="${w}" height="6" rx="3" fill="#48484a"/>` +
        (f > 0 ? `<rect x="${x}" y="12" width="${Math.max(6, w * f)}" height="6" rx="3" fill="${fill}"/>` : '')
      const W = 664
      const svg =
        `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="30" viewBox="0 0 ${W} 30" font-family="Segoe UI, system-ui, sans-serif" font-size="12">` +
        `<rect x=".5" y=".5" width="${W - 1}" height="29" rx="14.5" fill="#262628" stroke="#3a3a3d"/>` +
        `<text x="14" y="19" fill="#8e8e93">Cache</text>` +
        bar(58, 140, frac, hex) +
        `<text x="210" y="19" fill="${hex}" font-weight="600">${value}</text>` +
        `<rect x="296" y="8" width="1" height="14" fill="#3a3a3d"/>` +
        `<text x="310" y="19" fill="#8e8e93">Context</text>` +
        bar(362, 100, ctxFrac, ctxHex) +
        `<text x="474" y="19" fill="#f2f2f7" font-weight="600">${size > 0 ? `${Math.round(size / 1000)}K` : '-'}<tspan fill="#8e8e93" font-weight="400"> / ${NUDGE_AT / 1000}K</tspan></text>` +
        `<rect x="572" y="8" width="1" height="14" fill="#3a3a3d"/>` +
        `<text x="586" y="19" fill="#f2f2f7" font-weight="600">${pct !== null ? `${pct}%` : '-'}<tspan fill="#8e8e93" font-weight="400"> cached</tspan></text>` +
        `</svg>`
      return (
        <Box flexDirection="column">
          <Box paddingX={1}>
            <Svg source={svg} alt={`Prompt cache ${value}, context ${Math.round(size / 1000)}K`} width={W} height={30} />
          </Box>
          {rest}
        </Box>
      )
    }

    const filled = Math.ceil(frac * CELLS)
    return (
      <Box flexDirection="column">
        <Box paddingX={1}>
          <Text dimColor>{'Cache  '}</Text>
          <Text color={color}>{'█'.repeat(filled)}</Text>
          <Text color="gray">{'█'.repeat(CELLS - filled)}</Text>
          <Text color={color} bold>{`  ${value}`}</Text>
          {pct !== null && (
            <Text>
              <Text dimColor>{'   Last reply read from cache '}</Text>
              <Text bold>{`${pct}%`}</Text>
            </Text>
          )}
          {size > 0 && (
            <Text>
              <Text dimColor>{'   Context size '}</Text>
              <Text bold>{`${Math.round(size / 1000)}K`}</Text>
            </Text>
          )}
        </Box>
        {rest}
      </Box>
    )
  })
}
