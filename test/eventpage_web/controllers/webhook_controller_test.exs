defmodule EventpageWeb.WebhookControllerTest do
  use EventpageWeb.ConnCase

  import Eventpage.Fixtures

  alias Eventpage.CustomDomains.CustomDomain

  setup do
    %{acme: acme} = seed!()
    %{domain: domain!(acme, "hook.test", provider_uuid: "dom_hook")}
  end

  defp webhook(conn, token, event) do
    # Webhooks arrive on an internal hostname, which is in APP_HOSTS.
    post(conn, "/api/webhooks/saascustomdomains?token=#{token}", %{
      "event" => event,
      "domain" => %{"uuid" => "dom_hook", "host" => "hook.test"}
    })
  end

  test "applies events with the right token", %{conn: conn, domain: domain} do
    assert conn |> webhook("test_webhook_token", "domain_dns_proxy_record_valid") |> response(204)
    assert Eventpage.Repo.get(CustomDomain, domain.id).status == "active"
  end

  test "refuses a wrong or missing token", %{conn: conn, domain: domain} do
    assert conn |> webhook("guess", "domain_dns_proxy_record_valid") |> response(401)
    assert conn |> post("/api/webhooks/saascustomdomains", %{}) |> response(401)
    assert Eventpage.Repo.get(CustomDomain, domain.id).status == "pending"
  end

  test "acknowledges events for unknown domains", %{conn: conn} do
    conn =
      post(conn, "/api/webhooks/saascustomdomains?token=test_webhook_token", %{
        "event" => "domain_deleted",
        "domain" => %{"uuid" => "someone_else"}
      })

    assert response(conn, 204)
  end
end
