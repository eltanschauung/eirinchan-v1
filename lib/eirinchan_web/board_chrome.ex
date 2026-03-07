defmodule EirinchanWeb.BoardChrome do
  @moduledoc false

  @boardlist_groups [
    %{
      description: "0",
      links: [
        %{href: "/bant/index.html", label: "bant", title: "International Random"},
        %{href: "/trp/index.html", label: "trp", title: "Touhou Roleplay"},
        %{href: "/cp/index.html", label: "cp", title: "Chiruno Pictures"},
        %{href: "/j3/index.html", label: "j3", title: "Meta & Random"},
        %{href: "/qa/index.html", label: "qa", title: "Question & Answer"}
      ]
    },
    %{description: "1", links: [%{href: "/bant/rizz", label: "rizz", title: "Rizz"}]},
    %{
      description: "2",
      links: [
        %{href: "/faq", label: "faq", title: "FAQ"},
        %{href: "/formatting", label: "format", title: "Formatting"}
      ]
    },
    %{
      description: "3",
      links: [%{href: "https://gyate.net", label: "booru", title: "Booru"}]
    },
    %{
      description: "4",
      links: [%{href: "https://tf2.gyate.net", label: "opia", title: "Opia"}]
    },
    %{description: "5", links: [%{href: "/", label: "Home", title: "Home"}]}
  ]

  def for_board(%{uri: "bant"}) do
    default()
    |> Map.put(:subtitle, "losers, creeps, whales")
    |> Map.put(:show_default_announcement, false)
  end

  def for_board(_board), do: default()

  def default do
    %{
      subtitle: nil,
      boardlist_groups: @boardlist_groups,
      top_news_html: news_html(),
      post_form_blotter_html: ~s|<div class="blotter">Whale</div>|,
      footer_html: footer_html(),
      search_links: [
        %{href: "/__BOARD__/catalog.html", label: "[Orin]"},
        %{href: "https://archive.is/bantculture.com", label: "[Archive]"}
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

  def boardlist_groups(boards, chrome_groups \\ @boardlist_groups) do
    known_uris =
      chrome_groups
      |> Enum.flat_map(fn group ->
        Enum.map(group.links, fn link ->
          link.href
          |> String.trim("/")
          |> String.split("/", parts: 2)
          |> List.first()
        end)
      end)
      |> MapSet.new()

    dynamic_links =
      boards
      |> Enum.reject(&(MapSet.member?(known_uris, &1.uri) || &1.uri == "bant"))
      |> Enum.map(fn board ->
        %{href: "/#{board.uri}/index.html", label: board.uri, title: board.title}
      end)

    if dynamic_links == [] do
      chrome_groups
    else
      chrome_groups ++ [%{description: "dynamic", links: dynamic_links}]
    end
  end

  defp news_html do
    ~s|<!DOCTYPE html><html><head><title>news blotter</title></head><body><div id="blotterContainer" style="text-align: center;"><div class="news-button" onclick="toggleNews()">[View News - 02/14/26 🎄]</div><hr style="width: 100%; max-width: 500px;"><div class="news-blotter" style="width: 100%; max-width: 400px; margin: 0 auto;"><h1 style="font-size: 16pt; letter-spacing: -1px;">PSA Blotter</h1><table class="subtitle" style="font-size: 8pt; color: maroon;"><tr><td>02/14/26</td><td>/trp/ - Touhou Roleplay has been created for Valentine's Day</td></tr><tr><td>01/26/26</td><td>Wow guys, /qa/ has just been released!</td></tr><tr><td>12/21/25</td><td>Finally, a Christmas theme has arrived!</td></tr><tr><td>09/16/25</td><td>Huge Trumpflare update, posting is now easier than not</td></tr><tr><td>06/03/25</td><td>Replaced navigation arrows with Reisen &amp; Tewi, added Eientei theme</td></tr><tr><td>05/27/25</td><td>Upgraded spoilers, catalog and file selection... and added <span class="glow">Cloudflare</span></td></tr><tr><td>05/21/25</td><td>Our page limit and early 404 system just got updated; read about it <a href="../faq#prunes">Here!</a></td></tr><tr><td>04/01/25</td><td>Added nothing for April Fools</td></tr><tr><td>10/15/24</td><td>Oh fuck, this website is one year old 🎉</td></tr><tr><td>10/05/24</td><td>'Archive This Thread' now works, archive.org also functional</td></tr><tr><td>09/13/24</td><td>'polite sage' Email option is now real</td></tr><tr><td>08/30/24</td><td>A new BFC theme has replaced 'Keyed Frog' in the Options menu</td></tr><tr><td>07/04/24</td><td>Dead threads prune fast; <a href="../faq/#prunes">read about it!</a></td></tr><tr><td>06/10/24</td><td>.webp and .swf (with Ruffle) are here</td></tr><tr><td>06/05/24</td><td>Mobile rizz page... just got an apply button.</td></tr><tr><td>04/22/24</td><td>Updated embeds - New <a href="/j3">/j/</a> replacement</td></tr><tr><td>04/01/24</td><td>/bant/ no culture</td></tr><tr><td>01/10/24</td><td>Site upgrades and NSFW filter; click "Options" to test it out.</td></tr><tr><td>01/06/24</td><td>Triumph of the Whale (<a href="/formatting">formatting</a>)</td></tr><tr><td>12/23/23</td><td><a href="https://bantculture.com/bant/res/13043.html">Big Christmas Thing!</a></td></tr><tr><td>11/18/23</td><td><a href="https://bantculture.com/j/index.html">/j/</a> has been unlocked for site meta and to contain non-otaku shit</td></tr><tr><td>11/17/23</td><td>Removed all anti-spam. The hood has survived one month.</td></tr><tr><td>11/07/23</td><td>Upgraded rizz. Added <a href="../recent.html">recent</a>. Fixed large file uploads breaking.</td></tr><tr><td>11/06/23</td><td>The hood has breached 1000</td></tr><tr><td>11/03/23</td><td>log is out. It's called ORIN. It's because 3 syllables is bad for mewing.</td></tr><tr><td>10/15/23</td><td>Flags? DONE. Visit <a href="/bant/rizz/">>>>/rizz/</a></td></tr><tr><td>10/13/23</td><td>Holy FUARK. The circlejerk got LEAKED and there was an INVASION.</td></tr><tr><td>09/14/23</td><td>New playground invented: /bant/ - International/Random</td></tr></table><hr style="width: 100%; max-width: 500px;"></div></div></body></html><style>.subtitle td {  text-align:left;}.news-blotter {  display:none;}.news-button {  font-size: 10pt;  cursor: pointer;}</style><script>function toggleNews() {var newsBlotter = document.querySelector('.news-blotter');newsBlotter.style.display = newsBlotter.style.display === 'block' ? 'none' : 'block';}</script>|
  end

  defp footer_html do
    ~s|<footer><p class="unimportant" style="margin-top:20px;text-align:center;">We witches are not whale lol. I will never call 'whale' a Sukusuku though.</p><p class="unimportant" style="text-align:center;">All trademarks, copyrights, comments, and images on this page are owned by their respective parties because Gensokyo has laws</p></footer>|
  end
end
