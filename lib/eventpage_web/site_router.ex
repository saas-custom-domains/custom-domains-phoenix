defmodule EventpageWeb.SiteRouter do
  @moduledoc """
  Routes for organisers' custom domains. `EventpageWeb.HostRouter` only
  sends a request here after it found the organiser for the hostname.
  """
  use EventpageWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EventpageWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", EventpageWeb.Site do
    pipe_through :browser

    # The websocket has no Host-based pipeline, so the organiser travels
    # in the signed LiveView session (see EventpageWeb.SiteHost).
    live_session :site,
      session: {EventpageWeb.SiteHost, :session, []},
      on_mount: EventpageWeb.SiteHost do
      live "/", HomeLive
      live "/e/:slug", EventLive
    end
  end
end
