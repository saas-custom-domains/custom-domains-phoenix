defmodule EventpageWeb.HostRouter do
  @moduledoc """
  Finds the organiser from the request's hostname and hands the request
  to the right router:

    * your own hosts (`APP_HOSTS`) go to `EventpageWeb.Router` (dashboard,
      webhooks)
    * an organiser's active custom domain goes to `EventpageWeb.SiteRouter`
    * anything else gets a 404

  Behind SaaS Custom Domains, `Host` is your app's own hostname and the
  customer's domain arrives in `X-Served-For`. It's only trusted with the
  upstream's auth token, or anyone could claim any organiser's domain.
  """
  @behaviour Plug
  import Plug.Conn

  alias Eventpage.CustomDomains
  alias Eventpage.CustomDomains.Hosts

  def init(opts), do: opts

  def call(conn, _opts) do
    case served_for(conn) do
      :forbidden ->
        conn |> send_resp(403, "Forbidden") |> halt()

      served_for ->
        host = Hosts.normalize(served_for || conn.host)

        cond do
          Hosts.app_host?(host) ->
            EventpageWeb.Router.call(conn, [])

          organiser = CustomDomains.organiser_for_host(host) ->
            site_url = site_url(conn, host, served_for)

            # From here on Phoenix sees the customer's domain, as if the
            # browser had reached it directly: conn.host, LiveView's
            # host_uri, and url(conn, ~p"...") for absolute links.
            %{conn | host: host}
            |> assign(:organiser, organiser)
            |> assign(:site_url, site_url)
            |> Phoenix.Controller.put_router_url(site_url)
            |> EventpageWeb.SiteRouter.call([])

          true ->
            conn |> send_resp(404, "Unknown domain") |> halt()
        end
    end
  end

  # nil for direct requests, the customer's domain for proxied ones.
  defp served_for(conn) do
    case get_req_header(conn, "x-served-for") do
      [] ->
        nil

      [served_for | _] ->
        token = conn |> get_req_header("x-saas-domains-auth-token") |> List.first("")
        if valid_proxy_token?(token), do: served_for, else: :forbidden
    end
  end

  @doc """
  Constant-time comparison with the upstream's auth token. Refuses
  everything if the token isn't configured.
  """
  def valid_proxy_token?(token) do
    expected = Application.fetch_env!(:eventpage, :custom_domains)[:proxy_auth_token]
    expected not in [nil, ""] and Plug.Crypto.secure_compare(token, expected)
  end

  # The customer's scheme comes from the proxy (production always sends
  # https). Without the proxy (local development on *.localhost) use the
  # request's own scheme and port.
  defp site_url(conn, host, served_for) when is_binary(served_for) do
    scheme = conn |> get_req_header("x-forwarded-proto") |> List.first("https")
    "#{scheme}://#{host}"
  end

  defp site_url(conn, host, nil) do
    URI.to_string(%URI{scheme: Atom.to_string(conn.scheme), host: host, port: conn.port})
  end
end
