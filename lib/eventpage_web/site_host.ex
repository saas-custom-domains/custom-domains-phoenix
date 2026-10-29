defmodule EventpageWeb.SiteHost do
  @moduledoc """
  Carries the organiser from the HTTP request into the LiveView process.

  A LiveView runs twice: once in the HTTP request, where
  `EventpageWeb.HostRouter` has already found the organiser, and again
  over the websocket, which skips the endpoint's plugs and arrives with
  your app's own `Host`. So the hostname goes into the LiveView session,
  which Phoenix signs into the page, and `on_mount/4` looks the
  organiser up again from there.
  """
  import Phoenix.Component, only: [assign: 3, assign_new: 3]

  alias Eventpage.CustomDomains

  @doc """
  Runs during the HTTP request. The map is signed with the endpoint's
  secret, so the browser can't change it.
  """
  def session(conn) do
    %{"site_host" => conn.host, "site_url" => conn.assigns.site_url}
  end

  def on_mount(:default, _params, %{"site_host" => host, "site_url" => site_url}, socket) do
    # On the HTTP render this reuses conn.assigns.organiser. On the
    # websocket it runs the same lookup as the plug, so a domain
    # removed while the page was open stops working on reconnect.
    socket =
      socket
      |> assign_new(:organiser, fn -> CustomDomains.organiser_for_host(host) end)
      |> assign(:site_uri, URI.parse(site_url))

    if socket.assigns.organiser do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end
end
