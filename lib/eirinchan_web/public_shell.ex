defmodule EirinchanWeb.PublicShell do
  @moduledoc false

  @javascript_urls [
    "/main.js",
    "/js/jquery.min.js",
    "/js/inline-expanding.js",
    "/js/youtube.js",
    "/js/save-user_flag.js",
    "/js/thread-stats.js",
    "/js/strftime.min.js",
    "/js/ajax.js",
    "/js/file-selector.js",
    "/js/expand.js",
    "/js/options.js",
    "/js/style-select.js",
    "/js/options/general.js",
    "/js/options/user-js.js",
    "/js/options/user-css.js",
    "/js/jquery-ui.custom.min.js",
    "/js/quick-reply.js",
    "/js/filters.js",
    "/js/post-filter.js",
    "/js/local-time.js",
    "/js/titlebar-notifications.js",
    "/js/auto-reload.js",
    "/js/image-hover.js",
    "/js/post-hover.js",
    "/js/show-backlinks.js",
    "/js/show-op.js",
    "/js/show-own-posts-options.js",
    "/js/archive.js",
    "/js/mobile-style.js",
    "/js/fix-report-delete-submit.js",
    "/js/quick-post-controls.js",
    "/js/download-original.js",
    "/js/unspoiler3.js",
    "/js/ruffle.js",
    "/js/catalog-search.js",
    "/js/webm-settings.js",
    "/js/expand-video.js"
  ]

  def head_html(active_page, opts \\ []) do
    board_name =
      case Keyword.get(opts, :board_name) do
        nil -> "null"
        value -> ~s("#{value}")
      end

    """
    <script type="text/javascript">var active_page = "#{active_page}", board_name = #{board_name};</script><script type="text/javascript">var configRoot="/";var inMod = false;var modRoot="/"+(inMod ? "mod.php?/" : "");var resourceVersion="";</script>
    """
    |> String.trim()
  end

  def javascript_urls, do: @javascript_urls

  def body_end_html do
    "<script type=\"text/javascript\">ready();</script>"
  end
end
