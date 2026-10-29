defmodule EventpageWeb.HostRouterTest do
  use EventpageWeb.ConnCase

  import Eventpage.Fixtures

  setup %{conn: conn} do
    %{acme: acme, globex: globex} = seed!()
    domain!(acme, "events.acme.test", status: "active")
    domain!(globex, "events.globex.test")
    %{conn: conn}
  end

  defp on_host(conn, host), do: %{conn | host: host}

  defp via_proxy(conn, served_for, token \\ "test_proxy_token") do
    conn
    |> on_host("app.eventpage.test")
    |> put_req_header("x-served-for", served_for)
    |> put_req_header("x-saas-domains-auth-token", token)
  end

  test "the app's own host gets the dashboard", %{conn: conn} do
    assert conn |> on_host("localhost") |> get("/") |> html_response(200) =~ "Eventpage dashboard"
  end

  test "organiser pages are unreachable on the app's own host", %{conn: conn} do
    assert conn |> on_host("localhost") |> get("/e/latte-art-night") |> response(404)
  end

  test "an active custom domain gets the organiser's pages", %{conn: conn} do
    html = conn |> on_host("events.acme.test") |> get("/") |> html_response(200)
    assert html =~ "Acme Coffee"
    assert html =~ "Latte Art Night"
    refute html =~ "Design Systems Meetup"
  end

  test "the dashboard is unreachable on a custom domain", %{conn: conn} do
    refute conn |> on_host("events.acme.test") |> get("/") |> html_response(200) =~ "dashboard"

    assert conn
           |> on_host("events.acme.test")
           |> post("/api/webhooks/saascustomdomains")
           |> response(404)
  end

  test "another organiser's event slug is a 404", %{conn: conn} do
    assert_error_sent 404, fn ->
      conn |> on_host("events.acme.test") |> get("/e/design-systems-meetup")
    end
  end

  test "pending and unknown domains get a 404", %{conn: conn} do
    assert conn |> on_host("events.globex.test") |> get("/") |> response(404) == "Unknown domain"
    assert conn |> on_host("unknown.test") |> get("/") |> response(404) == "Unknown domain"
  end

  test "X-Served-For with the right token picks the organiser", %{conn: conn} do
    conn = conn |> via_proxy("events.acme.test") |> get("/e/latte-art-night")
    html = html_response(conn, 200)
    assert html =~ "Latte Art Night"
    # Absolute URLs use the customer's domain, not the endpoint's :url host.
    assert html =~ ~s(<link rel="canonical" href="https://events.acme.test/e/latte-art-night">)
    assert html =~ "https://events.acme.test/e/latte-art-night"
  end

  test "X-Served-For without the right token is refused", %{conn: conn} do
    assert conn |> via_proxy("events.acme.test", "") |> get("/") |> response(403)
    assert conn |> via_proxy("events.acme.test", "guess") |> get("/") |> response(403)

    spoofed = conn |> on_host("localhost") |> put_req_header("x-served-for", "events.acme.test")
    assert spoofed |> get("/") |> response(403)
  end

  test "X-Served-For is refused when no proxy token is configured", %{conn: conn} do
    config = Application.fetch_env!(:eventpage, :custom_domains)
    Application.put_env(:eventpage, :custom_domains, Keyword.put(config, :proxy_auth_token, nil))
    on_exit(fn -> Application.put_env(:eventpage, :custom_domains, config) end)

    assert conn |> via_proxy("events.acme.test", "") |> get("/") |> response(403)
  end

  test "the health check answers on any host", %{conn: conn} do
    assert conn |> on_host("10.0.0.5") |> get("/up") |> response(200) == "ok"
  end
end
