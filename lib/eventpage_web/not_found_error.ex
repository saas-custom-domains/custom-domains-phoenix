defmodule EventpageWeb.NotFoundError do
  @moduledoc "Raised for unknown event slugs; Phoenix renders it as a 404."
  defexception message: "not found", plug_status: 404
end
