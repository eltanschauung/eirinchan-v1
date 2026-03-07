defmodule EirinchanWeb.ThemeRegistry do
  @moduledoc false

  alias Eirinchan.Settings

  @static_stylesheet_dir Application.app_dir(:eirinchan, "priv/static/stylesheets")
  @internal_stylesheets MapSet.new([
                          "style.css",
                          "contrast.css",
                          "feedback.css",
                          "ipaccessauth.css",
                          "eirinchan-public.css",
                          "eirinchan-bant.css",
                          "eirinchan-mod.css"
                        ])

  @themes %{
    "default" => %{label: "Yotsuba", stylesheet: "/stylesheets/yotsuba.css"},
    "yotsuba" => %{label: "Yotsuba", stylesheet: "/stylesheets/yotsuba.css"},
    "vichan" => %{label: "Vichan", stylesheet: "/stylesheets/style.css"},
    "contrast" => %{label: "Contrast", stylesheet: "/stylesheets/contrast.css"},
    "feedback" => %{label: "Feedback", stylesheet: "/stylesheets/feedback.css"},
    "ipaccessauth" => %{label: "IpAccessAuth", stylesheet: "/stylesheets/ipaccessauth.css"},
    "christmas" => %{label: "Christmas", stylesheet: "/stylesheets/christmas.css"},
    "tomorrow" => %{label: "Tomorrow", stylesheet: "/stylesheets/tomorrow.css"}
  }

  @default_public_theme_names ["default", "tomorrow"]

  def all do
    themes()
    |> Enum.map(fn {name, theme} -> Map.put(theme, :name, name) end)
    |> Enum.sort_by(& &1.name)
  end

  def public_all do
    public_theme_names()
    |> Enum.map(&public_theme_entry/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.label)
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

  def canonical_public_name(name) when is_binary(name) do
    case fetch(name) do
      %{label: label} ->
        public_all()
        |> Enum.find_value(default_theme(), fn option ->
          if option.label == label, do: option.name
        end)

      _ ->
        default_theme()
    end
  end

  def canonical_public_name(_name), do: default_theme()

  defp themes do
    installed =
      Settings.installed_themes()
      |> Map.new(fn %{name: name, label: label, stylesheet: stylesheet} ->
        {name, %{label: label, stylesheet: stylesheet}}
      end)

    @themes
    |> Map.merge(detected_static_themes())
    |> Map.merge(installed)
  end

  defp detected_static_themes do
    @static_stylesheet_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".css"))
    |> Enum.reject(&MapSet.member?(@internal_stylesheets, &1))
    |> Map.new(fn filename ->
      name = Path.rootname(filename)
      {name, %{label: theme_label(name), stylesheet: "/stylesheets/#{filename}"}}
    end)
  end

  defp public_theme_names do
    configured =
      case Settings.current_instance_config() |> Map.get(:themes, %{}) |> Map.get(:public) do
        names when is_list(names) ->
          names
          |> Enum.map(&to_string/1)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        _ ->
          []
      end

    default_name = default_theme()

    (@default_public_theme_names ++ configured ++ [default_name])
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp public_theme_entry(name) do
    case fetch(name) do
      nil -> nil
      theme -> Map.put(theme, :name, name)
    end
  end

  defp theme_label(name) do
    name
    |> String.replace(~r/[_+-]+/, " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
