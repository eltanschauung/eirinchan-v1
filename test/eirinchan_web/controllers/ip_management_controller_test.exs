defmodule EirinchanWeb.IpManagementControllerTest do
  use EirinchanWeb.ConnCase, async: true

  alias Eirinchan.Repo

  test "board and global ip views expose posts and notes", %{conn: conn} do
    board = board_fixture()
    other_board = board_fixture()
    moderator = moderator_fixture(%{role: "mod"})

    grant_board_access_fixture(moderator, board)
    grant_board_access_fixture(moderator, other_board)

    thread = thread_fixture(board, %{body: "Board history body"})
    other_thread = thread_fixture(other_board, %{body: "Other history body"})

    {:ok, _thread} = Repo.update(Ecto.Changeset.change(thread, ip_subnet: "198.51.100.4"))
    {:ok, _other_thread} = Repo.update(Ecto.Changeset.change(other_thread, ip_subnet: "198.51.100.4"))

    note_conn =
      conn
      |> login_moderator(moderator)
      |> put_secure_manage_token()
      |> put_req_header("accept", "application/json")
      |> post("/manage/boards/#{board.uri}/ip/198.51.100.4/notes", %{"body" => "Watch this IP"})

    assert %{"data" => %{"ip_subnet" => "198.51.100.4", "body" => "Watch this IP"}} =
             json_response(note_conn, 201)

    board_view =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> put_req_header("accept", "application/json")
      |> get("/manage/boards/#{board.uri}/ip/198.51.100.4")

    assert %{"data" => %{"ip" => "198.51.100.4", "posts" => posts, "notes" => notes}} =
             json_response(board_view, 200)

    assert Enum.map(posts, & &1["id"]) == [thread.id]
    assert Enum.map(notes, & &1["body"]) == ["Watch this IP"]

    global_view =
      conn
      |> recycle()
      |> login_moderator(moderator)
      |> put_req_header("accept", "application/json")
      |> get("/manage/ip/198.51.100.4")

    assert %{"data" => %{"posts" => global_posts}} = json_response(global_view, 200)
    assert Enum.map(global_posts, & &1["id"]) == [other_thread.id, thread.id]
  end

  test "board ip views reject moderators without board access", %{conn: conn} do
    board = board_fixture()
    moderator = moderator_fixture(%{role: "mod"})

    conn =
      conn
      |> login_moderator(moderator)
      |> put_req_header("accept", "application/json")
      |> get("/manage/boards/#{board.uri}/ip/198.51.100.4")

    assert %{"error" => "forbidden"} = json_response(conn, 403)
  end
end
