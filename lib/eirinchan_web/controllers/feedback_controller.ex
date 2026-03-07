defmodule EirinchanWeb.FeedbackController do
  use EirinchanWeb, :controller

  alias Eirinchan.Boards
  alias Eirinchan.Feedback
  alias EirinchanWeb.RequestMeta

  def show(conn, _params) do
    render(conn, :show, boards: Boards.list_boards())
  end

  def create(conn, params) do
    case Feedback.create_feedback(params, remote_ip: RequestMeta.effective_remote_ip(conn)) do
      {:ok, entry} ->
        if params["json_response"] == "1" do
          json(conn, %{feedback_id: entry.id, status: "ok"})
        else
          redirect(conn, to: "/feedback")
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        if params["json_response"] == "1" do
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: translate_errors(changeset)})
        else
          conn
          |> put_status(:unprocessable_entity)
          |> render(:show,
            errors: translate_errors(changeset),
            params: params,
            boards: Boards.list_boards()
          )
        end
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
