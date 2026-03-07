defmodule EirinchanWeb.PostViewTest do
  use ExUnit.Case, async: true

  alias Eirinchan.Boards.BoardRecord
  alias Eirinchan.Posts.Post
  alias Eirinchan.Runtime.Config
  alias EirinchanWeb.PostView

  test "template_assigns exposes the compatibility contract" do
    board = %BoardRecord{uri: "files", title: "Files"}
    post = %Post{id: 10, subject: "Upload thread"}
    config = Config.compose()

    assigns = PostView.template_assigns(board, post, config)

    assert assigns.board == board
    assert assigns.board_title == "Files"
    assert assigns.post == post
    assert assigns.config == config
  end
end
