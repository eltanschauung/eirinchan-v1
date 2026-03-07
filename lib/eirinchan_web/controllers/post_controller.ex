defmodule EirinchanWeb.PostController do
  use EirinchanWeb, :controller

  alias Eirinchan.Posts

  plug EirinchanWeb.Plugs.LoadBoard

  def create(conn, params) do
    board = conn.assigns.current_board

    case Posts.create_post(board, params) do
      {:ok, post} ->
        respond_created(conn, board, post, params)

      {:error, :thread_not_found} ->
        respond_error(conn, :not_found, "Thread not found")

      {:error, %Ecto.Changeset{} = changeset} ->
        respond_error(conn, :unprocessable_entity, error_message(changeset))
    end
  end

  defp respond_created(conn, board, post, params) do
    thread_id = post.thread_id || post.id
    redirect_path = "/#{board.uri}/res/#{thread_id}.html#p#{post.id}"

    if params["json_response"] == "1" do
      json(conn, %{
        id: post.id,
        thread_id: thread_id,
        redirect: redirect_path
      })
    else
      redirect(conn, to: redirect_path)
    end
  end

  defp respond_error(conn, status, message) do
    if conn.params["json_response"] == "1" do
      conn
      |> put_status(status)
      |> json(%{error: message})
    else
      conn
      |> put_status(status)
      |> text(message)
    end
  end

  defp error_message(changeset) do
    Enum.map_join(changeset.errors, ", ", fn {field, {message, _opts}} ->
      "#{field} #{message}"
    end)
  end
end
