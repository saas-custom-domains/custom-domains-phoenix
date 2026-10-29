defmodule Eventpage.Repo.Migrations.CreateTables do
  use Ecto.Migration

  def change do
    create table(:organisers) do
      add :slug, :string, null: false
      add :name, :string, null: false
      add :tagline, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:organisers, [:slug])

    create table(:events) do
      add :organiser_id, references(:organisers, on_delete: :delete_all), null: false
      add :slug, :string, null: false
      add :title, :string, null: false
      add :starts_at, :utc_datetime, null: false
      add :venue, :string, null: false
      add :description, :text, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:events, [:organiser_id, :slug])

    create table(:rsvps) do
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :email, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:rsvps, [:event_id, :email])

    create table(:custom_domains) do
      add :organiser_id, references(:organisers, on_delete: :delete_all), null: false
      # Stored normalized (lowercase, no port, no trailing dot), so the
      # unique index really means "one organiser per hostname".
      add :host, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :https_ready, :boolean, null: false, default: false
      add :provider_uuid, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:custom_domains, [:host])
    create unique_index(:custom_domains, [:provider_uuid])
    create index(:custom_domains, [:organiser_id])
  end
end
