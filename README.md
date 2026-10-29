# Custom domains in Phoenix

An example Phoenix 1.8 and LiveView app where each customer serves their pages on their own domain. It's a small event pages product, Eventpage: every organiser gets a page per event with an RSVP form, and can put them on `events.theircompany.com` instead of an Eventpage URL.

[SaaS Custom Domains](https://saascustomdomains.com) does the routing and HTTPS: customers point a CNAME at it, it issues the certificate and forwards each request to the app.

It goes with the guide [How to Add Custom Domains to a Phoenix App](https://saascustomdomains.com/blog/posts/custom-domains-phoenix).

What's in it:

- `EventpageWeb.HostRouter` finds the organiser from the request's hostname and hands the request to one of two routers: the dashboard router for your own hosts, the site router for customer domains. Unknown and unverified domains get a 404.
- Requests from SaaS Custom Domains are accepted only with the upstream's auth token, so nobody can claim an organiser's domain by sending `X-Served-For` themselves.
- LiveView on customer domains: the socket's origin check, the session cookie, and how the organiser gets into the LiveView process (see [Phoenix gotchas](#phoenix-gotchas)).
- An RSVP form that's submitted over the LiveView websocket, with a live "going" count.
- A dashboard (also LiveView) to add a domain, check its DNS and remove it. Webhooks update it without a reload.

## Run it in 2 minutes

You need Docker.

```bash
git clone https://github.com/saas-custom-domains/custom-domains-phoenix
cd custom-domains-phoenix
docker compose up --build
```

1. Open http://localhost:4000 and add `acme.localhost` to Acme Coffee.
2. Within a few seconds the status changes to **Live**: the mock API "found" the DNS records and sent a webhook.
3. Open http://acme.localhost. The request goes through the mock proxy on port 80, the way a real customer domain goes through SaaS Custom Domains, and you see Acme's events. Open one and RSVP.

`*.localhost` always resolves to your own machine in Chrome, Firefox, Safari and curl, so there's nothing to add to `/etc/hosts`.

The mock is [scd-mock](https://github.com/saas-custom-domains/scd-mock): a local copy of the SaaS Custom Domains API and proxy, so you can try everything without an account.

### Run the app without Docker

You need Elixir 1.17 or newer. Start the mock in Docker, pointed at your machine:

```bash
docker run --rm -p 4010:4010 -p 80:4080 \
  -e SCD_MOCK_UPSTREAM_HOST=host.docker.internal \
  -e SCD_MOCK_UPSTREAM_PORT=4000 \
  -e SCD_MOCK_WEBHOOK_URL=http://host.docker.internal:4000/api/webhooks/saascustomdomains \
  -e SCD_MOCK_FORWARDED_PROTO=http \
  ghcr.io/saas-custom-domains/scd-mock:latest
```

Then, in another terminal:

```bash
mix setup
APP_HOSTS=localhost,host.docker.internal mix phx.server
```

In development the app talks to the mock on `localhost:4010` with the mock's tokens, so nothing else needs setting. On Linux, add `--add-host=host.docker.internal:host-gateway` to `docker run`.

## How it works

```
Browser ── events.acme.com ──▶ SaaS Custom Domains ──▶ your Phoenix app
                               (TLS certificate,       Host: app.eventpage.app
                                proxy)                 X-Served-For: events.acme.com
                                                       X-SaaS-Domains-Auth-Token: …
```

SaaS Custom Domains sends your app's own hostname in `Host` and `X-Forwarded-Host`, because that's what hosting platforms route on and what most apps expect. The customer's domain arrives in `X-Served-For`. This app needs the customer's domain for its routing, the LiveView socket and absolute links, so `HostRouter` checks the auth token, then sets `conn.host` to the customer's domain. From there Phoenix sees the request as if the browser had reached it directly. (If you'd rather receive the customer's domain in `X-Forwarded-Host`, our support can switch that on for your account.)

| File | What it does |
| --- | --- |
| `lib/eventpage_web/plugs/host_router.ex` | Checks the proxy token, finds the organiser, picks the router |
| `lib/eventpage_web/router.ex` | Your own hosts: dashboard and webhooks |
| `lib/eventpage_web/site_router.ex` | Customer domains: the organiser's LiveViews |
| `lib/eventpage_web/site_host.ex` | Carries the organiser into the LiveView process (`on_mount`) |
| `lib/eventpage_web/origin_check.ex` | `check_origin` for the LiveView socket |
| `lib/eventpage_web/endpoint.ex` | Socket and session settings, health check, `HostRouter` |
| `lib/eventpage/custom_domains.ex` | The hostname lookup; add, check and remove domains |
| `lib/eventpage/saas_custom_domains.ex` | API client for SaaS Custom Domains (Req) |
| `lib/eventpage_web/controllers/webhook_controller.ex` | Webhook endpoint |

Why two routers: `scope host: ...` in a Phoenix router only matches hosts you know when you write the router, and customer domains aren't known until runtime. Sending customer domains to their own router also makes the organiser pages unreachable on your own domain, and the dashboard unreachable on a customer's.

## Phoenix gotchas

### "Could not check origin for Phoenix.Socket transport."

On a customer domain, the page renders, then LiveView never connects: the RSVP button does nothing and the log shows:

```
[error] Could not check origin for Phoenix.Socket transport.

Origin of the request: https://events.acme.com

This happens when you are attempting a socket connection to
a different host than the one configured in your config/
files. ...
```

The default `check_origin: true` only accepts the host in `url: [host: ...]`, your own domain. `config/dev.exs` from `mix phx.new` sets `check_origin: false`, so this only shows up in production. Listing domains doesn't work because customers add new ones every day, and `check_origin: :conn` doesn't help either: Phoenix dispatches sockets before your endpoint plugs run, so `conn.host` is still your app's own host.

`endpoint.ex` passes a function instead, which accepts your own hosts and any active custom domain:

```elixir
@check_origin {EventpageWeb.OriginCheck, :allowed?, []}

socket "/live", Phoenix.LiveView.Socket,
  websocket: [connect_info: [session: @session_options], check_origin: @check_origin],
  longpoll: [connect_info: [session: @session_options], check_origin: @check_origin]
```

`test/eventpage_web/origin_check_test.exs` fails with the default setting.

### LiveView reloads the page in a loop, with nothing in the logs

LiveView refuses to mount when the websocket arrives without the session cookie, and the browser reloads the page to get a fresh one. The only message, "LiveView session was misconfigured or the user token is outdated.", is logged at debug level, so production logs show nothing.

Two ways to lose the cookie on a customer domain:

- A `:domain` in `@session_options`, often added for `*.eventpage.app` subdomains. Browsers drop a cookie for `eventpage.app` set by `events.acme.com`. Leave `:domain` out so each domain gets its own cookie.
- Phoenix marks cookies `Secure` when the request is HTTPS. Behind the proxy that's what you want. When you test the mock over plain `http://`, the browser drops the cookie, so `compose.yaml` sets `SCD_MOCK_FORWARDED_PROTO=http`. Production always sends `https`.

Phoenix's CSRF protection compares a token from the session with the one in the form and doesn't look at `Origin`, so once the cookie arrives, regular forms work on customer domains too.

### force_ssl sends customers to your own domain

`force_ssl` (`Plug.SSL`) redirects anything that looks like plain HTTP to `https://` plus the host from `url: [host: ...]`. SaaS Custom Domains terminates TLS and forwards with `X-Forwarded-Proto: https`; without `rewrite_on: [:x_forwarded_proto]` Phoenix ignores that header and sends every visitor of `events.acme.com` to `https://eventpage.app/...`. `config/prod.exs` keeps `rewrite_on` from the generator.

The redirect also catches machines that call your app over plain HTTP on an internal address: load balancer health checks (`GET /up` by IP) and, locally, the mock's webhooks. They're excluded with `exclude: [paths: ["/up", "/api/webhooks/saascustomdomains"], ...]`. `FORCE_SSL=false` turns the redirect off for `docker compose`, where everything is plain HTTP.

### Absolute URLs point at your own domain

`url(~p"/e/#{slug}")` and `url(@socket, ...)` build URLs from the endpoint's `url` config, so a share link or `<link rel="canonical">` on a customer's page points at `https://eventpage.app`. For controllers, `HostRouter` calls `put_router_url/2` with the customer's domain, so `url(conn, ...)` is right. In LiveView, `on_mount` assigns the customer's URL as a `%URI{}` and the templates use `url(@site_uri, ~p"/e/#{event.slug}")`. Relative paths (`~p"..."`) need nothing.

### Which organiser is this websocket for?

A LiveView mounts twice: in the HTTP request, which went through `HostRouter`, and again over the websocket, which didn't, and which arrives with your app's own `Host`. `site_router.ex` puts the hostname into the LiveView session with `live_session :site, session: {EventpageWeb.SiteHost, :session, []}`. Phoenix signs that session into the page, so the browser can't change it, and `SiteHost.on_mount/4` looks the organiser up again from it. If a domain is removed while a page is open, the next reconnect stops there.

## Use it with your SaaS Custom Domains account

1. [Create an API token](https://app.saascustomdomains.com/api_tokens) and an upstream pointing at your deployed app.
2. Set the environment variables: `SCD_API_TOKEN`, `SCD_ACCOUNT_UUID`, `SCD_UPSTREAM_UUID`, `PROXY_AUTH_TOKEN` (the upstream's auth token), `SCD_WEBHOOK_TOKEN` (from the webhook you create in the dashboard, pointing at `/api/webhooks/saascustomdomains`), `APP_HOSTS`, `APP_DOMAIN`, `PHX_HOST`, `SECRET_KEY_BASE` and `DATABASE_PATH`.
3. Leave `SCD_API_URL` unset so the client talks to the real API.

`APP_HOSTS` must list every hostname your own traffic arrives on: your app's domain, plus any internal name your platform uses to reach the app. `HostRouter` treats any other host as a customer domain and returns 404 if it isn't connected. (In `compose.yaml` that's why `app` is listed: webhooks from the mock arrive as `Host: app:4000`.) The health check at `/up` runs before `HostRouter`, because load balancers call it by IP address.

When an organiser adds a domain with a DNS contact, SaaS Custom Domains emails that person the records to add. Your customers point a CNAME at `in.saascustomdomains.com` (or A records at our two static IPs for a root domain). See the [docs](https://docs.saascustomdomains.com).

## Tests

```bash
mix test                       # unit and LiveView tests (ExUnit)
docker compose up -d --build --wait
npm install
npx playwright install chromium
npm run test:e2e               # end to end, through the mock proxy
```

The end-to-end tests use `*.test` domains, and Chromium resolves them to the mock proxy (a host-resolver rule in `playwright.config.ts`), so nothing depends on DNS or on port 80, and `Host` and `Origin` look like production. They cover the LiveView websocket through the proxy. To run a second stack side by side, set `APP_PORT`, `SCD_MOCK_API_PORT` and `SCD_MOCK_PROXY_PORT` for both `docker compose` and `npm run test:e2e`.

CI runs both on every push and once a week, so a new Phoenix or LiveView release that breaks something shows up here first.

## Tested with

| | Version |
| --- | --- |
| Phoenix | 1.8.16 |
| Phoenix LiveView | 1.2.13 |
| Elixir | 1.20.4 |
| Erlang/OTP | 29.1 |
| Ecto SQL / ecto_sqlite3 | 3.14.0 / 0.26.0 |
| Bandit | 1.14.1 |
| Req | 0.7.5 |

Last checked: 2026-10-29.

## Not production-ready on purpose

There's no login. In your app, check in every dashboard event handler that the signed-in user owns the organiser and the domain. SQLite keeps the example small; use your own database. With several app servers, add a cache in front of the hostname lookup if it shows up in your profiles, since every request and every socket connection runs it.

## License

MIT
