defmodule Eventpage.Events.Rsvp do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rsvps" do
    field :name, :string
    field :email, :string

    belongs_to :event, Eventpage.Events.Event

    timestamps(type: :utc_datetime)
  end

  def changeset(rsvp, attrs) do
    rsvp
    |> cast(attrs, [:name, :email])
    |> update_change(:email, &(&1 |> String.trim() |> String.downcase()))
    |> validate_required([:name, :email])
    |> validate_length(:name, max: 100)
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, message: "enter a valid email")
    |> unique_constraint([:event_id, :email],
      error_key: :email,
      message: "is already on the list"
    )
  end
end
