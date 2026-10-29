defmodule Eventpage.Repo do
  use Ecto.Repo,
    otp_app: :eventpage,
    adapter: Ecto.Adapters.SQLite3
end
