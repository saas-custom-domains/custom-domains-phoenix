defmodule EventpageWeb.Site.HomeLive do
  @moduledoc """
  An organiser's home page on their own domain: upcoming events.
  """
  use EventpageWeb, :site_live_view

  alias Eventpage.Events

  @impl true
  def mount(_params, _session, socket) do
    organiser = socket.assigns.organiser

    {:ok,
     socket
     |> assign(:page_title, organiser.name)
     |> assign(:canonical_url, url(socket.assigns.site_uri, ~p"/"))
     |> assign(:events, Events.list_events(organiser))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title={@organiser.name}>
      <h1 class="text-3xl font-semibold">{@organiser.name}</h1>
      <p class="text-base-content/70">{@organiser.tagline}</p>

      <ul class="space-y-3">
        <li :for={event <- @events}>
          <.link
            navigate={~p"/e/#{event.slug}"}
            class="card border border-base-300 p-4 hover:bg-base-200"
          >
            <span class="font-medium">{event.title}</span>
            <span class="text-sm text-base-content/70">{format_date(event.starts_at)}</span>
          </.link>
        </li>
      </ul>
    </Layouts.app>
    """
  end

  defp format_date(datetime), do: Calendar.strftime(datetime, "%a %-d %b, %H:%M UTC")
end
