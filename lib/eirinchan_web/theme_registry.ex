defmodule EirinchanWeb.ThemeRegistry do
  @moduledoc false

  @themes %{
    "default" => %{label: "Default", stylesheet: nil},
    "vichan" => %{label: "Vichan", stylesheet: "/stylesheets/style.css"},
    "contrast" => %{label: "Contrast", stylesheet: "/stylesheets/contrast.css"}
  }

  def all do
    @themes
    |> Enum.map(fn {name, theme} -> Map.put(theme, :name, name) end)
    |> Enum.sort_by(& &1.name)
  end

  def default_theme, do: "default"

  def fetch(name) when is_binary(name) do
    Map.get(@themes, String.trim(name))
  end

  def fetch(_name), do: nil

  def valid_theme?(name), do: not is_nil(fetch(name))
end
