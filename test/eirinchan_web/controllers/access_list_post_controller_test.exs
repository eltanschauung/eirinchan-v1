defmodule EirinchanWeb.AccessListPostControllerTest do
  use EirinchanWeb.ConnCase, async: false

  import Eirinchan.UploadsFixtures

  setup do
    previous = Application.get_env(:eirinchan, :ip_access_list, %{enabled: false, entries: []})

    on_exit(fn ->
      Application.put_env(:eirinchan, :ip_access_list, previous)
    end)

    :ok
  end

  test "disabled access list does not block multi-file OPs", %{conn: conn} do
    Application.put_env(:eirinchan, :ip_access_list, %{enabled: false, entries: []})
    board = board_fixture()

    conn =
      conn
      |> Map.put(:remote_ip, {203, 0, 113, 9})
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post(~p"/#{board.uri}/post", %{
        "body" => "multi file op",
        "files" => [
          upload_fixture("first.png", "first"),
          upload_fixture("second.gif", "second")
        ],
        "json_response" => "1",
        "post" => "New Topic"
      })

    assert %{"id" => _id} = json_response(conn, 200)
  end

  test "enabled access list blocks unlisted multi-file OPs and allows listed IPv4/IPv6 clients",
       %{
         conn: conn
       } do
    Application.put_env(:eirinchan, :ip_access_list, %{
      enabled: true,
      entries: ["198.51.100.0/24", "2001:db8:abcd::/48"]
    })

    board = board_fixture()

    blocked_conn =
      conn
      |> Map.put(:remote_ip, {203, 0, 113, 9})
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post(~p"/#{board.uri}/post", %{
        "body" => "blocked multi file op",
        "files" => [
          upload_fixture("first.png", "first"),
          upload_fixture("second.gif", "second")
        ],
        "json_response" => "1",
        "post" => "New Topic"
      })

    assert %{
             "error" => "IP not permitted for multi-file OP posting.",
             "error_code" => "access_list"
           } = json_response(blocked_conn, 403)

    allowed_ipv4_conn =
      conn
      |> recycle()
      |> Map.put(:remote_ip, {198, 51, 100, 7})
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post(~p"/#{board.uri}/post", %{
        "body" => "allowed ipv4 multi file op",
        "files" => [
          upload_fixture("first.png", "first"),
          upload_fixture("second.gif", "second")
        ],
        "json_response" => "1",
        "post" => "New Topic"
      })

    assert %{"id" => _id} = json_response(allowed_ipv4_conn, 200)

    allowed_ipv6_conn =
      conn
      |> recycle()
      |> Map.put(:remote_ip, {0x2001, 0x0DB8, 0xABCD, 0x1, 0, 0, 0, 1})
      |> put_req_header("referer", "http://www.example.com/#{board.uri}/index.html")
      |> post(~p"/#{board.uri}/post", %{
        "body" => "allowed ipv6 multi file op",
        "files" => [
          upload_fixture("first.png", "first"),
          upload_fixture("second.gif", "second")
        ],
        "json_response" => "1",
        "post" => "New Topic"
      })

    assert %{"id" => _id} = json_response(allowed_ipv6_conn, 200)
  end
end
