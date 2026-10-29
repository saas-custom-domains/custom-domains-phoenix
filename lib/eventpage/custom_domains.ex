defmodule Eventpage.CustomDomains do
  @moduledoc """
  Organisers' custom domains: the hostname lookup every organiser page
  depends on, and adding, checking and removing domains through the
  SaaS Custom Domains API, which also issues the certificates.

  This example has no login. In your app, check that the signed-in
  user owns the organiser and the domain before calling these.
  """
  import Ecto.Query
  require Logger

  alias Eventpage.CustomDomains.CustomDomain
  alias Eventpage.Events.Organiser
  alias Eventpage.{Repo, SaasCustomDomains}

  @topic "custom_domains"

  @doc """
  The organiser whose active domain is `host`, or nil. The one lookup
  every organiser page depends on; keep the unique index on `host`.
  """
  def organiser_for_host(host) do
    Repo.one(
      from o in Organiser,
        join: d in assoc(o, :custom_domains),
        where: d.host == ^host and d.status == "active"
    )
  end

  def active_host?(host) do
    Repo.exists?(from d in CustomDomain, where: d.host == ^host and d.status == "active")
  end

  def get_domain(id), do: Repo.get(CustomDomain, id)

  def change_domain(attrs \\ %{}), do: CustomDomain.create_changeset(%CustomDomain{}, attrs)

  def add_domain(%Organiser{} = organiser, attrs) do
    changeset = CustomDomain.create_changeset(%CustomDomain{organiser_id: organiser.id}, attrs)

    with {:ok, domain} <- Repo.insert(changeset),
         {:ok, domain} <- register(domain, attrs["dns_contact"]) do
      broadcast()
      {:ok, domain}
    end
  end

  defp register(domain, dns_contact) do
    case SaasCustomDomains.create_domain(domain.host, dns_contact) do
      {:ok, %{"uuid" => uuid}} ->
        domain |> Ecto.Changeset.change(provider_uuid: uuid) |> Repo.update()

      {:error, error} ->
        # Don't keep a row the proxy doesn't know about.
        Repo.delete!(domain)
        {:error, api_error(Ecto.Changeset.change(domain), error)}
    end
  end

  defp api_error(changeset, %SaasCustomDomains.Error{code: "host_taken"}) do
    Ecto.Changeset.add_error(
      changeset,
      :host,
      "That domain is already connected to another account."
    )
  end

  defp api_error(changeset, %SaasCustomDomains.Error{message: message}) do
    Logger.error("SaaS Custom Domains API: #{message}")
    Ecto.Changeset.add_error(changeset, :host, "Could not add the domain. Try again.")
  end

  @doc """
  Asks SaaS Custom Domains to check the domain's DNS records now,
  instead of waiting for the next scheduled check and its webhook.
  """
  def check_domain(%CustomDomain{provider_uuid: uuid} = domain) when is_binary(uuid) do
    case SaasCustomDomains.verify_dns(uuid) do
      {:ok, %{"dns_status" => "valid"}} -> {:ok, update!(domain, status: "active")}
      {:ok, _} -> {:ok, update!(domain, status: "pending")}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Proxy first, database second: if the API call fails, the row stays
  and the user can retry.
  """
  def remove_domain(%CustomDomain{} = domain) do
    with :ok <- unregister(domain) do
      Repo.delete!(domain)
      broadcast()
      :ok
    end
  end

  defp unregister(%{provider_uuid: uuid}) when is_binary(uuid),
    do: SaasCustomDomains.delete_domain(uuid)

  defp unregister(_), do: :ok

  @doc """
  Applies a SaaS Custom Domains webhook. Unknown domains (not ours, or
  already removed) are ignored. Events: https://docs.saascustomdomains.com/webhooks
  """
  def handle_webhook(event, %{"uuid" => uuid}) when is_binary(uuid) do
    case Repo.get_by(CustomDomain, provider_uuid: uuid) do
      nil -> :ignored
      domain -> apply_event(event, domain)
    end
  end

  def handle_webhook(_event, _domain), do: :ignored

  defp apply_event("domain_dns_proxy_record_valid", domain), do: update!(domain, status: "active")

  defp apply_event("domain_dns_proxy_record_invalid", domain),
    do: update!(domain, status: "pending")

  defp apply_event("tls_certificate_issued", domain), do: update!(domain, https_ready: true)
  defp apply_event(_event, _domain), do: :ignored

  defp update!(domain, changes) do
    domain = domain |> Ecto.Changeset.change(changes) |> Repo.update!()
    broadcast()
    domain
  end

  @doc """
  The dashboard subscribes, so webhooks show up without a reload.
  """
  def subscribe, do: Phoenix.PubSub.subscribe(Eventpage.PubSub, @topic)

  defp broadcast, do: Phoenix.PubSub.broadcast(Eventpage.PubSub, @topic, :domains_changed)
end
