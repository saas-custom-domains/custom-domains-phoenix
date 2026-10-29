defmodule Eventpage.Seeds do
  @moduledoc """
  Two organisers with a couple of events each. Runs on every start
  (see `Eventpage.Release.migrate/0`) and does nothing once seeded.
  """
  alias Eventpage.Events.{Event, Organiser}
  alias Eventpage.Repo

  def run do
    if Repo.aggregate(Organiser, :count) == 0 do
      insert(
        %Organiser{
          slug: "acme",
          name: "Acme Coffee",
          tagline: "Tastings and classes at the roastery."
        },
        [
          {"latte-art-night", "Latte Art Night", 7, "Acme Roastery, Bay 3",
           "Pour hearts, tulips and rosettas with our head barista. Milk and cups provided."},
          {"cupping-101", "Cupping 101", 14, "Acme Roastery, Tasting Room",
           "Taste six single origins side by side and learn how roasters score coffee."}
        ]
      )

      insert(
        %Organiser{slug: "globex", name: "Globex Studio", tagline: "Talks for teams that ship."},
        [
          {"design-systems-meetup", "Design Systems Meetup", 10, "Globex HQ, Floor 2",
           "Three short talks on keeping a component library alive past its first year."}
        ]
      )
    end

    :ok
  end

  defp insert(organiser, events) do
    organiser = Repo.insert!(organiser)
    today = DateTime.utc_now() |> DateTime.truncate(:second)

    for {slug, title, in_days, venue, description} <- events do
      Repo.insert!(%Event{
        organiser_id: organiser.id,
        slug: slug,
        title: title,
        starts_at:
          today |> DateTime.add(in_days, :day) |> Map.merge(%{hour: 18, minute: 30, second: 0}),
        venue: venue,
        description: description
      })
    end
  end
end
