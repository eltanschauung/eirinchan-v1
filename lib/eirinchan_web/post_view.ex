defmodule EirinchanWeb.PostView do
  @moduledoc false

  alias Eirinchan.Posts.PostFile

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

  def display_name(post, config) do
    case normalize_string(post.name) do
      nil -> config.anonymous
      value -> value
    end
  end

  def formatted_timestamp(%{inserted_at: %NaiveDateTime{} = inserted_at}) do
    Calendar.strftime(inserted_at, "%m/%d/%y(%a)%H:%M:%S")
  end

  def formatted_timestamp(%{inserted_at: %DateTime{} = inserted_at}) do
    Calendar.strftime(DateTime.to_naive(inserted_at), "%m/%d/%y(%a)%H:%M:%S")
  end

  def formatted_timestamp(_post), do: ""

  def all_files(post) do
    primary =
      if present?(post.file_path) do
        [
          %{
            file_name: post.file_name,
            file_path: post.file_path,
            thumb_path: post.thumb_path,
            file_size: post.file_size,
            file_type: post.file_type,
            image_width: post.image_width,
            image_height: post.image_height,
            spoiler: Map.get(post, :spoiler, false)
          }
        ]
      else
        []
      end

    primary ++ extra_files(post)
  end

  def file_display_name(file) do
    file.file_name ||
      case Map.get(file, :file_path) do
        nil -> "upload"
        path -> Path.basename(path)
      end
  end

  def file_info(file) do
    info =
      [human_file_size(file.file_size), dimensions(file)]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    if info == "" do
      file_display_name(file)
    else
      "#{file_display_name(file)} (#{info})"
    end
  end

  def primary_file?(_post, %PostFile{}), do: false

  def primary_file?(post, file),
    do: present?(post.file_path) and Map.get(file, :file_path) == post.file_path

  defp extra_files(%{extra_files: %Ecto.Association.NotLoaded{}}), do: []
  defp extra_files(%{extra_files: files}) when is_list(files), do: files
  defp extra_files(_post), do: []

  defp file_count(%{file_path: nil} = post), do: length(extra_files(post))
  defp file_count(post), do: 1 + length(extra_files(post))

  defp human_file_size(size) when is_integer(size) and size >= 1_048_576 do
    "#{Float.round(size / 1_048_576, 2)} MB"
  end

  defp human_file_size(size) when is_integer(size) and size >= 1024 do
    "#{Float.round(size / 1024, 1)} KB"
  end

  defp human_file_size(size) when is_integer(size) and size >= 0, do: "#{size} B"
  defp human_file_size(_size), do: nil

  defp dimensions(%{image_width: width, image_height: height})
       when is_integer(width) and is_integer(height),
       do: "#{width}x#{height}"

  defp dimensions(_file), do: nil

  defp normalize_string(nil), do: nil
  defp normalize_string(value) when is_binary(value), do: String.trim(value)

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)
end
