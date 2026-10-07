import type { Register } from 'claude-code'

type Pick = { question: string; labels: string[]; replies: Record<string, string> }

// ponytail: regex over the answer text; breaks if the "Quick Replies:" line or "A. option" format changes
const parse = (text: string): Pick | null => {
  const recommended = text.match(/Recommended:?\**\s*([A-D])\b/)?.[1]
  const first = text.search(/^\s*[-*]?\s*\**[A-D][.)]\**\s+/m)
  const lettered = new Map<string, string>()
  for (const m of text.matchAll(/^\s*[-*]?\s*\**([A-D])[.)]\**\s+(.*)$/gm)) {
    if (lettered.has(m[1])) continue
    // the card shows the letter and a short title; the chat only ever receives "option X"
    const title = m[2].replace(/[*_`]/g, '').split(/\s+[-(]|\s*\(Wins|:\s/)[0].trim()
    lettered.set(m[1], title.length > 44 ? `${title.slice(0, 43)}…` : title)
  }
  if (lettered.size >= 2) {
    const replies: Record<string, string> = {}
    const labels = [...lettered].slice(0, 4).map(([k, title]) => {
      const label = `${k}. ${title}${k === recommended ? ' (Recommended)' : ''}`
      replies[label] = `option ${k}`
      return label
    })
    const asked = text
      .slice(0, first)
      .split('\n')
      .map(l => l.replace(/[*_`#]/g, '').trim())
      .filter(l => l.endsWith('?'))
      .pop()
    return { question: asked ?? 'Which option?', labels, replies }
  }
  const line = text.match(/Quick Replies:\s*(.+)/)
  const phrases = line ? [...line[1].matchAll(/"([^"]{1,40})"/g)].map(m => m[1]).slice(0, 4) : []
  return phrases.length >= 2
    ? { question: 'Reply with?', labels: phrases, replies: Object.fromEntries(phrases.map(p => [p, p])) }
    : null
}

export const register: Register = on => {
  on('turn.complete', async ($, e, next) => {
    const pick = !e.agentId && e.answer ? parse(e.answer) : null
    if (pick) {
      // the engine's own AskUserQuestion card; not awaited so the turn finishes first; rejects when dismissed
      void $.ui
        .ask(pick.question, { options: pick.labels, header: 'Reply' })
        .then(answer => $.prompt.submit({ text: pick.replies[answer] ?? answer, asUser: true }))
        .catch(() => {})
    }
    return next(e)
  })
}
