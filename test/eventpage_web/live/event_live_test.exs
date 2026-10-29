defmodule EventpageWeb.Site.EventLiveTest do
  use EventpageWeb.ConnCase

  import Phoenix.LiveViewTest
  import Eventpage.Fixtures

  setup %{conn: conn} do
    %{acme: acme} = seed!()
    domain = domain!(acme, "events.acme.test", status: "active")
    %{conn: %{conn | host: "events.acme.test"}, domain: domain}
  end

  test "RSVP on a custom domain", %{conn: conn} do
    {:ok, view, html} = live(conn, "/e/latte-art-night")
    assert html =~ "Latte Art Night"
    assert view |> element("[data-testid=going]") |> render() =~ "0</strong> going"

    html =
      view
      |> form("#rsvp-form", rsvp: %{name: "Ada", email: "ada@example.com"})
      |> render_submit()

    assert html =~ "Thanks Ada, you&#39;re on the list for Latte Art Night."
    assert view |> element("[data-testid=going]") |> render() =~ "1</strong> going"

    html =
      view
      |> form("#rsvp-form", rsvp: %{name: "Ada", email: "ADA@example.com"})
      |> render_submit()

    assert html =~ "is already on the list"
  end

  test "the connected LiveView keeps the organiser from the signed session", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    assert render(view) =~ "Acme Coffee"
    assert view |> element("a", "Latte Art Night") |> render_click() |> follow_redirect(conn)
  end

  test "share links use the customer's domain", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/e/latte-art-night")

    assert view |> element("[data-testid=share-link]") |> render() =~
             "http://events.acme.test/e/latte-art-night"

    # What url/1 would have produced: the endpoint's own host.
    refute render(view) =~ EventpageWeb.Endpoint.url()
  end

  test "a removed domain stops working when the LiveView reconnects", %{
    conn: conn,
    domain: domain
  } do
    conn = get(conn, "/e/latte-art-night")
    Eventpage.Repo.delete!(domain)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn)
  end
end
