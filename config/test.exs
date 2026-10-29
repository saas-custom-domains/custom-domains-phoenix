import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :eventpage, Eventpage.Repo,
  database: Path.expand("../eventpage_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :eventpage, EventpageWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "aQar6P2cHvYkkK7a5DFgDe3B2lqmrAS0sze36eI3PTlgJli4qDA/AOibd9rryOXP",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

config :eventpage, :custom_domains,
  app_hosts: ["localhost", "www.example.com"],
  app_domain: "eventpage.app",
  proxy_auth_token: "test_proxy_token",
  webhook_token: "test_webhook_token"

# API calls go to Req.Test stubs instead of the network.
config :eventpage, Eventpage.SaasCustomDomains,
  base_url: "http://scd.test",
  api_token: "test_api_token",
  account_uuid: "acc_test",
  upstream_uuid: "upstream_test",
  req_options: [plug: {Req.Test, Eventpage.SaasCustomDomains}, retry: false]
