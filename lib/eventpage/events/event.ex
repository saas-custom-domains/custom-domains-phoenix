defmodule Eventpage.Events.Event do
  use Ecto.Schema

  schema "events" do
    field :slug, :string
    field :title, :string
    field :starts_at, :utc_datetime
    field :venue, :string
    field :description, :string

    belongs_to :organiser, Eventpage.Events.Organiser
    has_many :rsvps, Eventpage.Events.Rsvp

    timestamps(type: :utc_datetime)
  end
end
