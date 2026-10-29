defmodule EventpageWeb.OriginCheck do
  @moduledoc """
  `check_origin` for the LiveView socket. Phoenix calls `allowed?/1`
  with the parsed `Origin` header of every socket connection.
  """
  alias Eventpage.CustomDomains
  alias Eventpage.CustomDomains.Hosts

  def allowed?(%URI{host: host}) when is_binary(host) do
    host = Hosts.normalize(host)
    Hosts.app_host?(host) or CustomDomains.active_host?(host)
  end

  def allowed?(_uri), do: false
end
