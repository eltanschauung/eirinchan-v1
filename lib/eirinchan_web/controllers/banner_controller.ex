defmodule EirinchanWeb.BannerController do
  use EirinchanWeb, :controller

  alias Eirinchan.Settings

  def show(conn, _params) do
    case pick_banner(Settings.current_instance_config()) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("No banners configured.")

      banner ->
        redirect(conn, external: normalize_banner_url(banner))
    end
  end

  defp pick_banner(config) do
    config
    |> Map.get(:banners, [])
    |> Enum.filter(&(is_binary(&1) and String.trim(&1) != ""))
    |> Enum.random()
  rescue
    Enum.EmptyError -> nil
  end

  defp normalize_banner_url(url) do
    normalized = String.trim(url)

    cond do
      String.starts_with?(normalized, ["http://", "https://", "/"]) -> normalized
      true -> "/" <> normalized
    end
  end
end
