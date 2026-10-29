defmodule Eventpage.Fixtures do
  @moduledoc "Test data: the seeded organisers plus custom domains."
  alias Eventpage.CustomDomains.CustomDomain
  alias Eventpage.Events.Organiser
  alias Eventpage.Repo

  def seed! do
    Eventpage.Seeds.run()

    %{
      acme: Repo.get_by!(Organiser, slug: "acme"),
      globex: Repo.get_by!(Organiser, slug: "globex")
    }
  end

  def domain!(organiser, host, attrs \\ []) do
    Repo.insert!(struct!(CustomDomain, [organiser_id: organiser.id, host: host] ++ attrs))
  end
end
