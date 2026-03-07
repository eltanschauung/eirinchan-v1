defmodule EirinchanWeb.BoardManagementControllerTest do
  use EirinchanWeb.ConnCase, async: true

  test "creates, updates, shows, and deletes boards over HTTP", %{conn: conn} do
    conn = put_req_header(conn, "accept", "application/json")

    conn =
      post(conn, ~p"/manage/boards", %{
        uri: "tech",
        title: "Technology",
        subtitle: "Wired",
        config_overrides: %{force_body: true}
      })

    assert %{
             "data" => %{
               "uri" => "tech",
               "title" => "Technology",
               "subtitle" => "Wired",
               "config_overrides" => %{"force_body" => true}
             }
           } = json_response(conn, 201)

    assert %{"data" => %{"uri" => "tech"}} =
             conn |> recycle() |> get(~p"/manage/boards/tech") |> json_response(200)

    assert %{"data" => %{"title" => "Technology+"}} =
             conn
             |> recycle()
             |> patch(~p"/manage/boards/tech", %{title: "Technology+"})
             |> json_response(200)

    assert response(conn |> recycle() |> delete(~p"/manage/boards/tech"), 204)

    assert %{"error" => "not_found"} =
             conn |> recycle() |> get(~p"/manage/boards/tech") |> json_response(404)
  end

  test "board page loads through the DB-backed board context", %{conn: conn} do
    board = board_fixture(%{title: "Technology", subtitle: "Wired"})

    response =
      conn
      |> get(~p"/#{board.uri}")
      |> html_response(200)

    assert response =~ "/ #{board.uri} / - Technology"
    assert response =~ "Wired"
    assert response =~ "No threads yet."
  end
end
