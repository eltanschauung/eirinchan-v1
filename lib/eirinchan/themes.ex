defmodule Eirinchan.Themes do
  @moduledoc """
  Registry and persistence helpers for installable page themes.
  """

  alias Eirinchan.Settings

  @page_themes [
    %{
      name: "catalog",
      label: "Catalog",
      description: "Board and global catalog pages plus catalog JSON artifacts.",
      default_enabled: false
    },
    %{
      name: "ukko",
      label: "Ukko",
      description: "Cross-board thread index page.",
      default_enabled: true
    },
    %{
      name: "recent",
      label: "Recent",
      description: "Cross-board recent-posts page.",
      default_enabled: true
    },
    %{
      name: "sitemap",
      label: "Sitemap",
      description: "Public sitemap.xml generation.",
      default_enabled: true
    }
  ]

  def page_themes do
    enabled = enabled_page_theme_names()

    Enum.map(@page_themes, fn theme ->
      Map.put(theme, :enabled, theme.name in enabled)
    end)
  end

  def page_theme(name) when is_binary(name) do
    Enum.find(@page_themes, &(&1.name == String.trim(name)))
  end

  def page_theme(_name), do: nil

  def page_theme_enabled?(name) when is_binary(name) do
    String.trim(name) in enabled_page_theme_names()
  end

  def page_theme_enabled?(_name), do: false

  def enable_page_theme(name) when is_binary(name) do
    case page_theme(name) do
      nil -> {:error, :not_found}
      theme -> Settings.set_page_theme_enabled(theme.name, true)
    end
  end

  def disable_page_theme(name) when is_binary(name) do
    case page_theme(name) do
      nil -> {:error, :not_found}
      theme -> Settings.set_page_theme_enabled(theme.name, false)
    end
  end

  defp enabled_page_theme_names do
    case Settings.current_instance_config() |> Map.get(:themes, %{}) |> Map.get(:page_enabled, :unset) do
      :unset ->
        @page_themes
        |> Enum.filter(& &1.default_enabled)
        |> Enum.map(& &1.name)

      values when is_list(values) ->
        values
        |> Enum.map(&to_string/1)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.filter(&(not is_nil(page_theme(&1))))
        |> Enum.uniq()

      _ ->
        []
    end
  end
end
