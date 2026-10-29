defmodule EventpageWeb.DashboardLive do
  @moduledoc """
  The organisers' dashboard on your own domain: connect a custom domain,
  see its status, check DNS, remove it. Webhooks update it live.

  This example has no login. In your app, check that the signed-in user
  owns the organiser (and the domain) in every event handler.
  """
  use EventpageWeb, :live_view

  alias Eventpage.{CustomDomains, Events}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: CustomDomains.subscribe()

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:errors, %{})
     |> load_organisers()}
  end

  @impl true
  def handle_event("add", %{"organiser_id" => id} = params, socket) do
    organiser = Enum.find(socket.assigns.organisers, &(to_string(&1.id) == id))

    case CustomDomains.add_domain(organiser, params) do
      {:ok, _domain} ->
        {:noreply, socket |> assign(:errors, %{}) |> load_organisers()}

      {:error, changeset} ->
        message = changeset |> error_messages() |> Enum.join(" ")
        {:noreply, assign(socket, :errors, %{organiser.id => message})}
    end
  end

  def handle_event("check", %{"id" => id}, socket) do
    with %{} = domain <- CustomDomains.get_domain(id),
         {:error, _} <- CustomDomains.check_domain(domain) do
      {:noreply, put_flash(socket, :error, "Could not check #{domain.host}. Try again.")}
    else
      _ -> {:noreply, load_organisers(socket)}
    end
  end

  def handle_event("remove", %{"id" => id}, socket) do
    with %{} = domain <- CustomDomains.get_domain(id),
         {:error, _} <- CustomDomains.remove_domain(domain) do
      {:noreply, put_flash(socket, :error, "Could not remove #{domain.host}. Try again.")}
    else
      _ -> {:noreply, load_organisers(socket)}
    end
  end

  # Webhooks change domains in another process.
  @impl true
  def handle_info(:domains_changed, socket), do: {:noreply, load_organisers(socket)}

  defp load_organisers(socket), do: assign(socket, :organisers, Events.list_organisers())

  defp error_messages(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Map.values()
    |> List.flatten()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title="Eventpage dashboard">
      <p class="text-base-content/70">Connect a custom domain to each organiser's event pages.</p>

      <section
        :for={organiser <- @organisers}
        class="card border border-base-300 p-5 space-y-3"
        data-testid={"organiser-#{organiser.slug}"}
      >
        <h2 class="text-lg font-medium">{organiser.name}</h2>

        <ul class="space-y-2">
          <li
            :for={domain <- organiser.custom_domains}
            class="flex items-center gap-3 text-sm"
            data-testid={"domain-#{domain.host}"}
          >
            <span class="font-mono">{domain.host}</span>
            <.status_badge domain={domain} />
            <button class="link ml-auto" phx-click="check" phx-value-id={domain.id}>Check DNS</button>
            <button class="link text-error" phx-click="remove" phx-value-id={domain.id}>Remove</button>
          </li>
        </ul>

        <form phx-submit="add" class="flex flex-wrap gap-2">
          <input type="hidden" name="organiser_id" value={organiser.id} />
          <input
            name="host"
            required
            placeholder="events.example.com"
            aria-label="Domain"
            class="input flex-1"
          />
          <input
            name="dns_contact"
            type="email"
            placeholder="DNS contact (optional)"
            aria-label="DNS contact email"
            class="input flex-1"
          />
          <button class="btn btn-primary" phx-disable-with="Adding...">Add domain</button>
          <p :if={@errors[organiser.id]} role="alert" class="w-full text-sm text-error">
            {@errors[organiser.id]}
          </p>
        </form>
      </section>
    </Layouts.app>
    """
  end

  defp status_badge(assigns) do
    ~H"""
    <span class={["badge", if(@domain.status == "active", do: "badge-success", else: "badge-warning")]}>
      {cond do
        @domain.status != "active" -> "Waiting for DNS"
        @domain.https_ready -> "Live"
        true -> "DNS OK, waiting for HTTPS"
      end}
    </span>
    """
  end
end
