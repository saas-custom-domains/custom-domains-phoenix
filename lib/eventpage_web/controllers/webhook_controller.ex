defmodule EventpageWeb.WebhookController do
  use EventpageWeb, :controller

  alias Eventpage.CustomDomains

  # Events: https://docs.saascustomdomains.com/webhooks
  def create(conn, params) do
    if valid_token?(params["token"]) do
      # Unknown domains (not ours, or already removed) are acknowledged
      # too, so they aren't retried.
      CustomDomains.handle_webhook(params["event"], params["domain"])
      send_resp(conn, 204, "")
    else
      send_resp(conn, 401, "Unauthorized")
    end
  end

  defp valid_token?(token) do
    expected = Application.fetch_env!(:eventpage, :custom_domains)[:webhook_token]
    is_binary(token) and expected not in [nil, ""] and Plug.Crypto.secure_compare(token, expected)
  end
end
