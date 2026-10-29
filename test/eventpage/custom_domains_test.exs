defmodule Eventpage.CustomDomainsTest do
  use Eventpage.DataCase

  import Eventpage.Fixtures

  alias Eventpage.CustomDomains
  alias Eventpage.CustomDomains.CustomDomain

  setup do
    Req.Test.verify_on_exit!()
    seed!()
  end

  describe "organiser_for_host/1" do
    test "finds the organiser of an active domain only", %{acme: acme, globex: globex} do
      domain!(acme, "events.acme.test", status: "active")
      domain!(globex, "events.globex.test")

      assert CustomDomains.organiser_for_host("events.acme.test").id == acme.id
      assert CustomDomains.organiser_for_host("events.globex.test") == nil
      assert CustomDomains.organiser_for_host("unknown.test") == nil
    end
  end

  describe "add_domain/2" do
    test "registers the domain with SaaS Custom Domains", %{acme: acme} do
      Req.Test.expect(Eventpage.SaasCustomDomains, fn conn ->
        assert conn.method == "POST"

        assert conn.request_path ==
                 "/api/v1/accounts/acc_test/upstreams/upstream_test/custom_domains"

        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test_api_token"]
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(body) == %{
                 "host" => "events.acme.test",
                 "instructions_recipient" => "it@acme.test"
               }

        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(%{"uuid" => "dom_1", "host" => "events.acme.test"})
      end)

      assert {:ok, domain} =
               CustomDomains.add_domain(acme, %{
                 "host" => "Events.Acme.Test",
                 "dns_contact" => "it@acme.test"
               })

      assert domain.host == "events.acme.test"
      assert domain.provider_uuid == "dom_1"
      assert domain.status == "pending"
    end

    test "rejects our own domains and invalid hosts without calling the API", %{acme: acme} do
      assert {:error, changeset} =
               CustomDomains.add_domain(acme, %{"host" => "admin.eventpage.app"})

      assert errors_on(changeset).host == ["That's one of our domains."]

      assert {:error, changeset} = CustomDomains.add_domain(acme, %{"host" => "not a domain"})
      assert errors_on(changeset).host == ["Enter a valid domain, like events.example.com."]
    end

    test "rejects a host another organiser already has", %{acme: acme, globex: globex} do
      domain!(globex, "events.globex.test")

      assert {:error, changeset} =
               CustomDomains.add_domain(acme, %{"host" => "events.globex.test"})

      assert errors_on(changeset).host == ["That domain is already connected to an organiser."]
    end

    test "doesn't keep the row when the API refuses the domain", %{acme: acme} do
      Req.Test.expect(Eventpage.SaasCustomDomains, fn conn ->
        conn
        |> Plug.Conn.put_status(400)
        |> Req.Test.json(%{
          "error" => "Host has already been taken",
          "error_code" => "host_taken"
        })
      end)

      assert {:error, changeset} = CustomDomains.add_domain(acme, %{"host" => "taken.test"})
      assert errors_on(changeset).host == ["That domain is already connected to another account."]
      refute Repo.get_by(CustomDomain, host: "taken.test")
    end
  end

  describe "check_domain/1" do
    test "takes the status from verify_dns_records", %{acme: acme} do
      domain = domain!(acme, "check.test", provider_uuid: "dom_check")

      Req.Test.expect(Eventpage.SaasCustomDomains, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ ~r"/custom_domains/dom_check/verify_dns_records$"
        Req.Test.json(conn, %{"dns_status" => "valid", "host" => "check.test"})
      end)

      assert {:ok, %{status: "active"}} = CustomDomains.check_domain(domain)

      Req.Test.expect(
        Eventpage.SaasCustomDomains,
        &Req.Test.json(&1, %{"dns_status" => "invalid"})
      )

      assert {:ok, %{status: "pending"}} = CustomDomains.check_domain(domain)
    end
  end

  describe "remove_domain/1" do
    test "treats 404 from the API as already removed", %{acme: acme} do
      domain = domain!(acme, "gone.test", provider_uuid: "dom_gone")

      Req.Test.expect(Eventpage.SaasCustomDomains, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path =~ ~r"/custom_domains/dom_gone$"

        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{
          "error" => "Custom domain dom_gone not found.",
          "error_code" => "not_found"
        })
      end)

      assert :ok = CustomDomains.remove_domain(domain)
      refute Repo.get(CustomDomain, domain.id)
    end

    test "keeps the row when the API call fails, so it can be retried", %{acme: acme} do
      domain = domain!(acme, "retry.test", provider_uuid: "dom_retry")
      Req.Test.expect(Eventpage.SaasCustomDomains, &Plug.Conn.send_resp(&1, 500, "oops"))

      assert {:error, _} = CustomDomains.remove_domain(domain)
      assert Repo.get(CustomDomain, domain.id)
    end
  end

  describe "handle_webhook/2" do
    test "updates the status from webhook events", %{acme: acme} do
      domain = domain!(acme, "hook.test", provider_uuid: "dom_hook")
      payload = %{"uuid" => "dom_hook", "host" => "hook.test"}

      CustomDomains.handle_webhook("domain_dns_proxy_record_valid", payload)
      assert %{status: "active", https_ready: false} = Repo.get(CustomDomain, domain.id)

      CustomDomains.handle_webhook("tls_certificate_issued", payload)
      assert %{status: "active", https_ready: true} = Repo.get(CustomDomain, domain.id)

      CustomDomains.handle_webhook("domain_dns_proxy_record_invalid", payload)
      assert %{status: "pending"} = Repo.get(CustomDomain, domain.id)
    end

    test "ignores domains it doesn't know" do
      assert CustomDomains.handle_webhook("domain_dns_proxy_record_valid", %{"uuid" => "nope"}) ==
               :ignored
    end
  end
end
