defmodule Eventpage.Events.Organiser do
  use Ecto.Schema

  schema "organisers" do
    field :slug, :string
    field :name, :string
    field :tagline, :string

    has_many :events, Eventpage.Events.Event
    has_many :custom_domains, Eventpage.CustomDomains.CustomDomain

    timestamps(type: :utc_datetime)
  end
end
