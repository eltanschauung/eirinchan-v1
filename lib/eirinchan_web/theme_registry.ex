defmodule EirinchanWeb.ThemeRegistry do
  @moduledoc false

  alias Eirinchan.Settings

  @themes %{
    "default" => %{label: "Yotsuba", stylesheet: "/stylesheets/yotsuba.css"},
    "yotsuba" => %{label: "Yotsuba", stylesheet: "/stylesheets/yotsuba.css"},
    "vichan" => %{label: "Vichan", stylesheet: "/stylesheets/style.css"},
    "contrast" => %{label: "Contrast", stylesheet: "/stylesheets/contrast.css"},
    "feedback" => %{label: "Feedback", stylesheet: "/stylesheets/feedback.css"},
    "ipaccessauth" => %{label: "IpAccessAuth", stylesheet: "/stylesheets/ipaccessauth.css"}
  }

  def all do
    themes()
    |> Enum.map(fn {name, theme} -> Map.put(theme, :name, name) end)
    |> Enum.sort_by(& &1.name)
  end

  def default_theme do
    case Settings.default_theme() do
      value when is_binary(value) and value != "" -> value
      _ -> "default"
    end
  end

  def fetch(name) when is_binary(name) do
    Map.get(themes(), String.trim(name))
  end

  def fetch(_name), do: nil

  def valid_theme?(name), do: not is_nil(fetch(name))

  defp themes do
    installed =
      Settings.installed_themes()
      |> Map.new(fn %{name: name, label: label, stylesheet: stylesheet} ->
        {name, %{label: label, stylesheet: stylesheet}}
      end)

    Map.merge(@themes, installed)
  end
end
