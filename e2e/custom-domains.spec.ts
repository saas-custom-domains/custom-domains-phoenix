import { expect, test, type Page } from '@playwright/test'

// Customer domains go through the mock proxy (see playwright.config.ts).
// Use the browser (page.goto) for them: the host-resolver rule only
// applies to Chromium, not to Playwright's request API.
const customerUrl = (host: string, path = '/') => `http://${host}${path}`

async function connectDomain(page: Page, organiser: string, host: string) {
  await page.goto('/')
  await liveViewConnected(page)
  const card = page.getByTestId(`organiser-${organiser}`)
  await card.getByLabel('Domain', { exact: true }).fill(host)
  await card.getByRole('button', { name: 'Add domain' }).click()
  const row = page.getByTestId(`domain-${host}`)
  await expect(row).toBeVisible()
  return row
}

// LiveView adds phx-connected once its websocket has joined.
async function liveViewConnected(page: Page) {
  await expect(page.locator('[data-phx-main].phx-connected')).toBeVisible()
}

test('connect a domain, RSVP over LiveView through the proxy, remove it', async ({
  page,
  context,
}) => {
  const host = `acme-${Date.now()}.test`
  const row = await connectDomain(page, 'acme', host)

  // The mock marks *.test as pointed after ~2s and sends webhooks. The
  // dashboard is subscribed over PubSub, so no reload is needed.
  await expect(row).toContainText('Live', { timeout: 15_000 })

  // The LiveView socket goes through the proxy too, with Origin
  // http://<host>. It only connects if check_origin accepts the domain.
  const socket = page.waitForEvent('websocket')
  await page.goto(customerUrl(host))
  await expect(page.getByRole('heading', { name: 'Acme Coffee' })).toBeVisible()
  await expect(page).toHaveTitle('Acme Coffee')
  expect((await socket).url()).toContain(`ws://${host}/live/websocket`)
  await liveViewConnected(page)

  // Live navigation to the event page, over the same websocket.
  await page.getByRole('link', { name: /Latte Art Night/ }).click()
  await expect(page).toHaveURL(customerUrl(host, '/e/latte-art-night'))
  await liveViewConnected(page)

  // Absolute links use the customer's domain, not the endpoint's host.
  await expect(page.getByTestId('share-link')).toHaveText(
    `http://${host}/e/latte-art-night`,
  )

  // A second visitor sees the count change live.
  const other = await context.newPage()
  await other.goto(customerUrl(host, '/e/latte-art-night'))
  await liveViewConnected(other)
  const before = Number(await other.getByTestId('going').locator('strong').textContent())

  await page.getByLabel('Name').fill('Ada')
  await page.getByLabel('Email').fill(`ada-${Date.now()}@example.com`)
  await page.getByRole('button', { name: 'RSVP' }).click()
  await expect(page.getByRole('status')).toHaveText(
    "Thanks Ada, you're on the list for Latte Art Night.",
  )
  await expect(other.getByTestId('going')).toContainText(`${before + 1} going`)

  await page.goto('/')
  await liveViewConnected(page)
  await row.getByRole('button', { name: 'Remove' }).click()
  await expect(row).toBeHidden()
  const gone = await page.goto(customerUrl(host))
  expect(gone?.status()).toBe(404)
})

test('a domain that does not point at us stays pending', async ({ page }) => {
  const host = `events-${Date.now()}.example.com`
  const row = await connectDomain(page, 'globex', host)

  await row.getByRole('button', { name: 'Check DNS' }).click()
  await expect(row).toContainText('Waiting for DNS')

  await row.getByRole('button', { name: 'Remove' }).click()
  await expect(row).toBeHidden()
})

test('rejects our own domains', async ({ page }) => {
  await page.goto('/')
  await liveViewConnected(page)
  const card = page.getByTestId('organiser-acme')
  await card.getByLabel('Domain', { exact: true }).fill('admin.eventpage.app')
  await card.getByRole('button', { name: 'Add domain' }).click()
  await expect(card.getByRole('alert')).toHaveText("That's one of our domains.")
})

test('organiser pages are not served on the app host', async ({ request }) => {
  const res = await request.get('/e/latte-art-night')
  expect(res.status()).toBe(404)
})

test('requests that skip the proxy cannot claim a domain', async ({ request }) => {
  const spoofed = await request.get('/', {
    headers: { 'X-Served-For': 'acme.test' },
  })
  expect(spoofed.status()).toBe(403)

  const wrongToken = await request.get('/', {
    headers: {
      'X-Served-For': 'acme.test',
      'X-SaaS-Domains-Auth-Token': 'guess',
    },
  })
  expect(wrongToken.status()).toBe(403)
})

test('webhooks need the right token', async ({ request }) => {
  const res = await request.post('/api/webhooks/saascustomdomains?token=x', {
    data: { event: 'domain_dns_proxy_record_valid', domain: { uuid: 'x' } },
  })
  expect(res.status()).toBe(401)
})

test('unknown domains get a 404', async ({ page }) => {
  const res = await page.goto(customerUrl('unknown.test'))
  expect(res?.status()).toBe(404)
})
