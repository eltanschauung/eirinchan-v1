defmodule EirinchanWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use EirinchanWeb, :controller` and
  `use EirinchanWeb, :live_view`.
  """
  use EirinchanWeb, :html

  embed_templates "layouts/*"

  def versioned_asset(path, nil), do: path
  def versioned_asset(path, ""), do: path

  def versioned_asset(path, version) do
    separator = if String.contains?(path, "?"), do: "&", else: "?"
    "#{path}#{separator}v=#{URI.encode_www_form(to_string(version))}"
  end
end
