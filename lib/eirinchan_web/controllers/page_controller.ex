defmodule EirinchanWeb.PageController do
  use EirinchanWeb, :controller

  alias Eirinchan.Boards
  alias Eirinchan.Installation

  def home(conn, _params) do
    if Installation.setup_required?() do
      redirect(conn, to: ~p"/setup")
    else
      render(conn, :home, layout: false, boards: Boards.list_boards())
    end
  end
end
