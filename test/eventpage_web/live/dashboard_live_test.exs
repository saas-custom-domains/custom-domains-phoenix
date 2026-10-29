defmodule EventpageWeb.DashboardLiveTest do
  use EventpageWeb.ConnCase

  import Phoenix.LiveViewTest
  import Eventpage.Fixtures

  setup do
    %{acme: acme} = seed!()
    %{acme: acme}
  end

  test "adds a domain and shows its status", %{conn: conn, acme: acme} do
    {:ok, view, _html} = live(conn, "/")
    Req.Test.allow(Eventpage.SaasCustomDomains, self(), view.pid)

    Req.Test.expect(Eventpage.SaasCustomDomains, fn conn ->
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"uuid" => "dom_1"})
    end)

    view
    |> element("[data-testid=organiser-acme] form")
    |> render_submit(%{"organiser_id" => acme.id, "host" => "events.acme.test"})

    assert view |> element("[data-testid='domain-events.acme.test']") |> render() =~
             "Waiting for DNS"

    # A webhook in another process updates the page.
    Eventpage.CustomDomains.handle_webhook("domain_dns_proxy_record_valid", %{"uuid" => "dom_1"})
    assert render(view) =~ "DNS OK, waiting for HTTPS"
    Eventpage.CustomDomains.handle_webhook("tls_certificate_issued", %{"uuid" => "dom_1"})
    assert render(view) =~ "Live"
  end

  test "rejects our own domains", %{conn: conn, acme: acme} do
    {:ok, view, _html} = live(conn, "/")

    html =
      view
      |> element("[data-testid=organiser-acme] form")
      |> render_submit(%{"organiser_id" => acme.id, "host" => "admin.eventpage.app"})

    assert html =~ "That&#39;s one of our domains."
  end
end
