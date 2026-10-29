defmodule Eventpage.SaasCustomDomains do
  @moduledoc """
  A small client for the SaaS Custom Domains API.
  Docs: https://docs.saascustomdomains.com/custom-domains
  """

  defmodule Error do
    defexception [:status, :code, :message]
  end

  def create_domain(host, instructions_recipient \\ nil) do
    # We email instructions_recipient the exact DNS records to add.
    body =
      %{host: host, instructions_recipient: instructions_recipient}
      |> Map.reject(fn {_, v} -> v in [nil, ""] end)

    request(:post, "", json: body)
  end

  def verify_dns(uuid), do: request(:post, "/#{uuid}/verify_dns_records")

  def delete_domain(uuid) do
    case request(:delete, "/#{uuid}") do
      # Already gone is fine: the goal is that it doesn't exist.
      {:error, %Error{status: 404}} -> :ok
      {:error, error} -> {:error, error}
      {:ok, _} -> :ok
    end
  end

  defp request(method, path, opts \\ []) do
    config = Application.fetch_env!(:eventpage, __MODULE__)

    [
      method: method,
      base_url:
        "#{config[:base_url]}/api/v1/accounts/#{config[:account_uuid]}" <>
          "/upstreams/#{config[:upstream_uuid]}/custom_domains",
      url: path,
      auth: {:bearer, config[:api_token]},
      receive_timeout: 10_000
    ]
    |> Keyword.merge(config[:req_options] || [])
    |> Keyword.merge(opts)
    |> Req.request()
    |> case do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error,
         %Error{
           status: status,
           code: is_map(body) && body["error_code"],
           message: (is_map(body) && body["error"]) || "HTTP #{status}"
         }}

      {:error, exception} ->
        {:error, %Error{message: Exception.message(exception)}}
    end
  end
end
