defmodule EirinchanWeb.PostView do
  @moduledoc false

  def template_assigns(board, post, config) do
    %{
      board: board,
      board_title: board.title,
      post: post,
      config: config
    }
  end

  def post_title(_board, post, config) do
    cond do
      present?(post.subject) ->
        post.subject

      config.fileboard && present?(post.file_name) ->
        post.file_name

      is_nil(post.thread_id) ->
        "Thread ##{post.id}"

      true ->
        "Reply ##{post.id}"
    end
  end

  def show_body?(post, config) do
    present?(post.body) or not config.fileboard
  end

  def fileboard_summary(post) do
    count = file_count(post)
    noun = if count == 1, do: "file", else: "files"
    "#{count} #{noun}"
  end

  def show_fileboard_summary?(post), do: file_count(post) > 0

  def feedback_actions do
    [
      %{key: "mark_read", label: "Mark as Read", method: "PATCH"},
      %{key: "add_note", label: "Add Note", method: "POST"},
      %{key: "delete", label: "Delete", method: "DELETE"}
    ]
  end

  defp extra_files(%{extra_files: %Ecto.Association.NotLoaded{}}), do: []
  defp extra_files(%{extra_files: files}) when is_list(files), do: files
  defp extra_files(_post), do: []

  defp file_count(%{file_path: nil} = post), do: length(extra_files(post))
  defp file_count(post), do: 1 + length(extra_files(post))

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)
end
