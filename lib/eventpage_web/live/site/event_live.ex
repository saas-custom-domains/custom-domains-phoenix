defmodule EventpageWeb.Site.EventLive do
  @moduledoc """
  One event page with an RSVP form. The form is submitted over the
  LiveView websocket, so it only works on a custom domain if the socket
  passes `check_origin` (see EventpageWeb.OriginCheck).
  """
  use EventpageWeb, :site_live_view

  alias Eventpage.Events

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    # Scoped to the organiser from the hostname, never from the URL.
    event = Events.get_event(socket.assigns.organiser, slug) || raise EventpageWeb.NotFoundError
    if connected?(socket), do: Events.subscribe(event)

    {:ok,
     socket
     |> assign(:page_title, "#{event.title} · #{socket.assigns.organiser.name}")
     |> assign(:event, event)
     |> assign(:going, Events.count_rsvps(event))
     |> assign(:confirmation, nil)
     # url/1 and url(@socket, ...) would use the endpoint's :url host
     # (your own domain). Build links from the customer's domain instead.
     |> assign(:share_url, url(socket.assigns.site_uri, ~p"/e/#{event.slug}"))
     |> assign(:canonical_url, url(socket.assigns.site_uri, ~p"/e/#{event.slug}"))
     |> assign(:form, to_form(Events.change_rsvp()))}
  end

  @impl true
  def handle_event("rsvp", %{"rsvp" => params}, socket) do
    case Events.create_rsvp(socket.assigns.event, params) do
      {:ok, rsvp} ->
        {:noreply,
         socket
         |> assign(
           :confirmation,
           "Thanks #{rsvp.name}, you're on the list for #{socket.assigns.event.title}."
         )
         |> assign(:form, to_form(Events.change_rsvp()))}

      {:error, changeset} ->
        {:noreply, socket |> assign(:confirmation, nil) |> assign(:form, to_form(changeset))}
    end
  end

  # Another visitor RSVP'd.
  @impl true
  def handle_info({:rsvp_count, count}, socket), do: {:noreply, assign(socket, :going, count)}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title={@organiser.name}>
      <.link navigate={~p"/"} class="link text-sm">All events</.link>
      <h1 class="text-3xl font-semibold">{@event.title}</h1>
      <p class="text-base-content/70">
        {Calendar.strftime(@event.starts_at, "%A %-d %B, %H:%M UTC")} · {@event.venue}
      </p>
      <p>{@event.description}</p>
      <p data-testid="going"><strong>{@going}</strong> going</p>

      <.form for={@form} id="rsvp-form" phx-submit="rsvp" class="space-y-2">
        <.input field={@form[:name]} label="Name" required />
        <.input field={@form[:email]} type="email" label="Email" required />
        <.button phx-disable-with="Saving...">RSVP</.button>
      </.form>
      <p :if={@confirmation} role="status" class="text-success">{@confirmation}</p>

      <p class="text-sm text-base-content/70">
        Share: <a href={@share_url} class="link" data-testid="share-link">{@share_url}</a>
      </p>
    </Layouts.app>
    """
  end
end
