defmodule Eventpage.Events do
  @moduledoc """
  Organisers (the tenants), their event pages and RSVPs.
  """
  import Ecto.Query

  alias Eventpage.Events.{Event, Organiser, Rsvp}
  alias Eventpage.Repo

  def list_organisers do
    Repo.all(
      from o in Organiser, order_by: o.id, preload: [custom_domains: ^custom_domains_query()]
    )
  end

  defp custom_domains_query, do: from(d in Eventpage.CustomDomains.CustomDomain, order_by: d.id)

  def list_events(%Organiser{id: id}) do
    Repo.all(from e in Event, where: e.organiser_id == ^id, order_by: e.starts_at)
  end

  # Always scoped to the organiser: a slug from another organiser's
  # page must not resolve on this domain.
  def get_event(%Organiser{id: id}, slug) do
    Repo.get_by(Event, organiser_id: id, slug: slug)
  end

  def count_rsvps(%Event{id: id}) do
    Repo.aggregate(from(r in Rsvp, where: r.event_id == ^id), :count)
  end

  def change_rsvp(attrs \\ %{}), do: Rsvp.changeset(%Rsvp{}, attrs)

  def create_rsvp(%Event{} = event, attrs) do
    result =
      %Rsvp{event_id: event.id}
      |> Rsvp.changeset(attrs)
      |> Repo.insert()

    with {:ok, _rsvp} <- result do
      Phoenix.PubSub.broadcast(Eventpage.PubSub, topic(event), {:rsvp_count, count_rsvps(event)})
    end

    result
  end

  def subscribe(%Event{} = event), do: Phoenix.PubSub.subscribe(Eventpage.PubSub, topic(event))

  defp topic(event), do: "event:#{event.id}"
end
