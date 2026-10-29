defmodule Eventpage.CustomDomains.CustomDomain do
  use Ecto.Schema
  import Ecto.Changeset

  alias Eventpage.CustomDomains.Hosts

  schema "custom_domains" do
    field :host, :string
    # "pending" until DNS points at the proxy, then "active".
    field :status, :string, default: "pending"
    field :https_ready, :boolean, default: false
    field :provider_uuid, :string

    belongs_to :organiser, Eventpage.Events.Organiser

    timestamps(type: :utc_datetime)
  end

  def create_changeset(domain, attrs) do
    domain
    |> cast(attrs, [:host])
    |> update_change(:host, &Hosts.normalize/1)
    |> validate_required([:host], message: "Enter a domain.")
    |> validate_change(:host, fn :host, host ->
      cond do
        not Hosts.valid?(host) -> [host: "Enter a valid domain, like events.example.com."]
        Hosts.reserved?(host) -> [host: "That's one of our domains."]
        true -> []
      end
    end)
    |> unique_constraint(:host, message: "That domain is already connected to an organiser.")
  end
end
