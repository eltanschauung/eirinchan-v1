defmodule EirinchanWeb.BoardHTML do
  use EirinchanWeb, :html

  alias Eirinchan.Posts
  alias EirinchanWeb.PostView

  def captcha_enabled?(config), do: Posts.captcha_required?(config, true)

  embed_templates "board_html/*"
end
