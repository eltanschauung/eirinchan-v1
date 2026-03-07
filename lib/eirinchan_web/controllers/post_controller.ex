defmodule EirinchanWeb.PostController do
  use EirinchanWeb, :controller

  alias Eirinchan.Posts
  alias Eirinchan.Reports
  alias Eirinchan.ThreadPaths

  plug EirinchanWeb.Plugs.LoadBoard

  def create(conn, params) do
    board = conn.assigns.current_board
    config = conn.assigns.current_board_config

    request = %{referer: List.first(get_req_header(conn, "referer"))}

    case branch(params) do
      :report ->
        case Reports.create_report(board, params) do
          {:ok, report} ->
            respond_reported(conn, board, report, params)

          {:error, reason} when is_atom(reason) ->
            respond_error(conn, error_status(reason), error_message(reason, config))

          {:error, %Ecto.Changeset{} = changeset} ->
            respond_error(conn, :unprocessable_entity, error_message(changeset))
        end

      :post ->
        case Posts.create_post(board, params, config: config, request: request) do
          {:ok, post, meta} ->
            respond_created(conn, board, post, params, meta)

          {:error, reason} when is_atom(reason) ->
            respond_error(conn, error_status(reason), error_message(reason, config))

          {:error, %Ecto.Changeset{} = changeset} ->
            respond_error(conn, :unprocessable_entity, error_message(changeset))
        end
    end
  end

  defp respond_created(conn, board, post, params, meta) do
    thread_id = post.thread_id || post.id
    config = conn.assigns.current_board_config

    redirect_path =
      if meta.noko do
        suffix = if post.thread_id, do: "#p#{post.id}", else: ""
        "#{thread_redirect_path(board, post, thread_id, config)}#{suffix}"
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

  defp thread_redirect_path(board, %{thread_id: nil} = thread, _thread_id, config) do
    ThreadPaths.thread_path(board, thread, config)
  end

  defp thread_redirect_path(board, _post, thread_id, config) do
    case Posts.get_thread(board, thread_id) do
      {:ok, [thread | _]} -> ThreadPaths.thread_path(board, thread, config)
      {:error, :not_found} -> "/#{board.uri}/res/#{thread_id}.html"
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

  defp respond_reported(conn, board, report, params) do
    redirect_path =
      thread_redirect_or_board(board, report.thread_id, params, conn.assigns.current_board_config)

    if params["json_response"] == "1" do
      json(conn, %{report_id: report.id, redirect: redirect_path, status: "ok"})
    else
      redirect(conn, to: redirect_path)
    end
  end

  defp branch(params) do
    if Map.has_key?(params, "report_post_id"), do: :report, else: :post
  end

  defp thread_redirect_or_board(board, nil, _params, _config), do: "/#{board.uri}"

  defp thread_redirect_or_board(board, thread_id, params, config) do
    if params["report_page"] == "board" do
      "/#{board.uri}"
    else
      case Posts.get_thread(board, thread_id) do
        {:ok, [thread | _]} -> ThreadPaths.thread_path(board, thread, config)
        {:error, :not_found} -> "/#{board.uri}/res/#{thread_id}.html"
      end
    end
  end

  defp error_status(:thread_not_found), do: :not_found
  defp error_status(:post_not_found), do: :not_found
  defp error_status(:thread_locked), do: :forbidden
  defp error_status(:invalid_referer), do: :forbidden
  defp error_status(:invalid_post_mode), do: :forbidden
  defp error_status(:board_locked), do: :forbidden
  defp error_status(:reply_hard_limit), do: :unprocessable_entity
  defp error_status(:body_required), do: :unprocessable_entity

  defp error_message(:thread_not_found, _config), do: "Thread not found"
  defp error_message(:post_not_found, _config), do: "Post not found"
  defp error_message(:thread_locked, config), do: config.error.locked
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
