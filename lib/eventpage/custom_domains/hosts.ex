defmodule Eventpage.CustomDomains.Hosts do
  @moduledoc """
  Hostname rules. Pure functions, configured in `config/runtime.exs`.
  """

  @doc """
  "Acme.Example.com." and "acme.example.com:443" are the same host.
  """
  def normalize(host) when is_binary(host) do
    host
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/:\d+$/, "")
    |> String.trim_trailing(".")
  end

  def normalize(_), do: ""

  @label ~r/^(?!-)[a-z0-9-]{1,63}(?<!-)$/

  def valid?(host) do
    labels = String.split(host, ".")
    byte_size(host) <= 253 and length(labels) >= 2 and Enum.all?(labels, &(&1 =~ @label))
  end

  @doc """
  Hostnames that serve the app itself (the dashboard, webhooks), not
  an organiser's pages. Include every name your own traffic arrives on.
  """
  def app_hosts, do: config(:app_hosts)

  def app_host?(host), do: host in app_hosts()

  @doc """
  Our own domains, which organisers can't connect.
  """
  def reserved?(host) do
    app_domain = config(:app_domain)

    app_host?(host) or
      (app_domain not in [nil, ""] and
         (host == app_domain or String.ends_with?(host, "." <> app_domain)))
  end

  defp config(key), do: Application.fetch_env!(:eventpage, :custom_domains)[key]
end
