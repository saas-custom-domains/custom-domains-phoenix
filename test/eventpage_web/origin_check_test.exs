defmodule EventpageWeb.OriginCheckTest do
  use EventpageWeb.ConnCase

  import ExUnit.CaptureLog
  import Eventpage.Fixtures

  setup do
    %{acme: acme, globex: globex} = seed!()
    domain!(acme, "events.acme.test", status: "active")
    domain!(globex, "events.globex.test")
    :ok
  end

  # The LiveView socket, requested the way the browser does on a custom
  # domain behind the proxy: Host is your app, Origin is the customer's.
  defp connect_socket(conn, origin) do
    conn
    |> Map.put(:host, "app.eventpage.test")
    |> put_req_header("origin", origin)
    |> get("/live/websocket", %{"vsn" => "2.0.0"})
  end

  test "accepts the socket from an active custom domain", %{conn: conn} do
    log =
      capture_log(fn -> refute connect_socket(conn, "https://events.acme.test").status == 403 end)

    refute log =~ "Could not check origin"
  end

  test "accepts the socket from the app's own host", %{conn: conn} do
    refute connect_socket(conn, "http://localhost:4000").status == 403
  end

  test "refuses the socket from pending and unknown domains", %{conn: conn} do
    log =
      capture_log(fn ->
        assert connect_socket(conn, "https://events.globex.test").status == 403
        assert connect_socket(conn, "https://evil.test").status == 403
      end)

    assert log =~ "Could not check origin for Phoenix.Socket transport."
  end

  test "Phoenix's default check_origin refuses every custom domain" do
    # What `check_origin: true` (the default) does: compare with the
    # endpoint's url: [host: ...] only.
    conn =
      Phoenix.ConnTest.build_conn(:get, "/live/websocket")
      |> put_req_header("origin", "https://events.acme.test")

    log =
      capture_log(fn ->
        conn =
          Phoenix.Socket.Transport.check_origin(
            conn,
            Phoenix.LiveView.Socket,
            EventpageWeb.Endpoint,
            check_origin: true
          )

        assert conn.status == 403
      end)

    assert log =~ "Could not check origin for Phoenix.Socket transport."
  end
end
