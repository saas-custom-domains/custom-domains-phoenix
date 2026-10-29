defmodule EventpageWeb.Router do
  @moduledoc """
  Routes for your own hosts (`APP_HOSTS`): the dashboard and webhooks. Organiser pages live in `EventpageWeb.SiteRouter`,
  so they're unreachable here.
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

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", EventpageWeb do
    pipe_through :browser

    live "/", DashboardLive
  end

  scope "/api", EventpageWeb do
    pipe_through :api

    post "/webhooks/saascustomdomains", WebhookController, :create
  end
end
