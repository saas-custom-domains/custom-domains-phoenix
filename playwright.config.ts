import { defineConfig } from '@playwright/test'

const appPort = process.env.APP_PORT ?? '4000'
const proxyPort = process.env.SCD_MOCK_PROXY_PORT ?? '80'

// Runs against `docker compose up`. Chromium resolves every customer
// domain (*.test) to the mock proxy, the way DNS sends a real customer
// domain to SaaS Custom Domains. Host and Origin stay "acme-....test"
// whatever port the mock listens on, so several stacks can run side by
// side. (A host-resolver rule rather than an HTTP proxy setting, because
// Chromium tunnels websockets through an HTTP proxy with CONNECT, and
// LiveView needs its websocket.)
export default defineConfig({
  testDir: 'e2e',
  timeout: 30_000,
  use: {
    baseURL: `http://localhost:${appPort}`,
    launchOptions: {
      args: [`--host-resolver-rules=MAP *.test 127.0.0.1:${proxyPort}`],
    },
    trace: 'retain-on-failure',
  },
})
