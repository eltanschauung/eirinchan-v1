defmodule EirinchanWeb.ThreadHTML do
  use EirinchanWeb, :html

  alias Eirinchan.Posts

  def captcha_enabled?(config), do: Posts.captcha_required?(config, false)

  embed_templates "thread_html/*"
end
