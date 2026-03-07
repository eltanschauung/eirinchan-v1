defmodule EirinchanWeb.PostController do
  use EirinchanWeb, :controller

  alias Eirinchan.Posts

  plug EirinchanWeb.Plugs.LoadBoard

  def create(conn, params) do
    board = conn.assigns.current_board
    config = conn.assigns.current_board_config

    case Posts.create_post(board, params,
           config: config,
           request: %{referer: List.first(get_req_header(conn, "referer"))}
         ) do
      {:ok, post, meta} ->
        respond_created(conn, board, post, params, meta)

      {:error, reason} when is_atom(reason) ->
        respond_error(conn, error_status(reason), error_message(reason, config))

      {:error, %Ecto.Changeset{} = changeset} ->
        respond_error(conn, :unprocessable_entity, error_message(changeset))
    end
  end

  defp respond_created(conn, board, post, params, meta) do
    thread_id = post.thread_id || post.id

    redirect_path =
      if meta.noko do
        suffix = if post.thread_id, do: "#p#{post.id}", else: ""
        "/#{board.uri}/res/#{thread_id}.html#{suffix}"
      else
        "/#{board.uri}"
      end

    if params["json_response"] == "1" do
      json(conn, %{
        id: post.id,
        thread_id: thread_id,
        redirect: redirect_path,
        noko: meta.noko
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

  defp error_status(:thread_not_found), do: :not_found
  defp error_status(:invalid_referer), do: :forbidden
  defp error_status(:invalid_post_mode), do: :forbidden
  defp error_status(:board_locked), do: :forbidden
  defp error_status(:reply_hard_limit), do: :unprocessable_entity
  defp error_status(:body_required), do: :unprocessable_entity

  defp error_message(:thread_not_found, _config), do: "Thread not found"
  defp error_message(:invalid_referer, config), do: config.error.referer
  defp error_message(:invalid_post_mode, config), do: config.error.bot
  defp error_message(:board_locked, config), do: config.error.board_locked
  defp error_message(:reply_hard_limit, config), do: config.error.reply_hard_limit
  defp error_message(:body_required, config), do: config.error.tooshort_body

  defp error_message(changeset) do
    Enum.map_join(changeset.errors, ", ", fn {field, {message, _opts}} ->
      "#{field} #{message}"
    end)
  end
end
