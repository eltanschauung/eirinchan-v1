defmodule EirinchanWeb.BoardHTML do
  use EirinchanWeb, :html

  alias Eirinchan.Posts
  alias EirinchanWeb.PostView

  def captcha_enabled?(config), do: Posts.captcha_required?(config, true)
  def reply_captcha_enabled?(config), do: Posts.captcha_required?(config, false)

  embed_templates "board_html/*"
end
