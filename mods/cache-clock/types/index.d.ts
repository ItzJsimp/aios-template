declare module 'claude-code' {
  interface PluginState {
    'cache-clock': { lastAt: number | null; now: number; tokens: number; hit: number | null }
  }
}
