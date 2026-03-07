defmodule EirinchanWeb.PageController do
  use EirinchanWeb, :controller

  alias Eirinchan.Boards

  def home(conn, _params) do
    render(conn, :home, layout: false, boards: Boards.list_boards())
  end
end
