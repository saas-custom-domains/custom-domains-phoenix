defmodule EventpageWeb.HealthCheck do
  @moduledoc """
  `GET /up` for Docker and load balancers. It sits in the endpoint
  before the host check, because health checks arrive by IP address.
  """
  @behaviour Plug
  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{method: "GET", path_info: ["up"]} = conn, _opts) do
    conn |> send_resp(200, "ok") |> halt()
  end

  def call(conn, _opts), do: conn

  @doc """
  Used by `force_ssl` in config/prod.exs: `FORCE_SSL=false` (docker
  compose, plain HTTP) skips the HTTPS redirect.
  """
  def skip_https_redirect?(_conn), do: not Application.get_env(:eventpage, :force_ssl, true)
end
