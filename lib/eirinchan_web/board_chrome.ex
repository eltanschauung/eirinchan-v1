defmodule EirinchanWeb.BoardChrome do
  @moduledoc false

  def for_board(_board), do: default()

  def default do
    %{
      subtitle: nil,
      boardlist_groups: nil,
      top_news_html: nil,
      post_form_blotter_html: nil,
      footer_html: footer_html(),
      search_links: [
        %{href: "/__BOARD__/catalog.html", label: "[Catalog]"}
      ],
      show_default_announcement: true
    }
  end

  def search_links(board_uri) do
    default()
    |> Map.fetch!(:search_links)
    |> Enum.map(fn link ->
      %{link | href: String.replace(link.href, "__BOARD__", board_uri)}
    end)
  end

  def boardlist_groups(boards, nil), do: EirinchanWeb.PostView.boardlist_groups(boards)
  def boardlist_groups(_boards, chrome_groups), do: chrome_groups

  defp footer_html do
    ~s|<footer><p class="unimportant" style="margin-top:20px;text-align:center;">Powered by Eirinchan.</p></footer>|
  end
end
