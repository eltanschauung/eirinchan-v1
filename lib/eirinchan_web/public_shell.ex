defmodule EirinchanWeb.PublicShell do
  @moduledoc false

  def head_html(active_page, opts \\ []) do
    board_name =
      case Keyword.get(opts, :board_name) do
        nil -> "null"
        value -> ~s("#{value}")
      end

    """
    <script type="text/javascript">var active_page = "#{active_page}", board_name = #{board_name};</script><script type="text/javascript">var configRoot="/";var inMod = false;var modRoot="/"+(inMod ? "mod.php?/" : "");</script>
    """
    |> String.trim()
  end

  def javascript_urls, do: ["/main.js"]

  def body_end_html do
    "<script type=\"text/javascript\">ready();</script>"
  end
end
