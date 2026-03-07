defmodule EirinchanWeb.PostView do
  @moduledoc false

  alias Eirinchan.Posts.PostFile
  alias Eirinchan.ThreadPaths

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

  def board_heading(board), do: "/#{board.uri}/ - #{board.title}"

  def thread_path(board, post, config), do: ThreadPaths.thread_path(board, post, config)

  def reply_path(board, thread, post, config, mode \\ :post) do
    suffix =
      case mode do
        :quote -> "#q#{post.id}"
        _ -> "#p#{post.id}"
      end

    thread_path(board, thread, config) <> suffix
  end

  def boardlist_groups(boards) do
    [
      Enum.map(boards, fn board ->
        %{
          href: "/#{board.uri}/index.html",
          label: board.uri,
          title: board.title
        }
      end),
      [%{href: "/", label: "Home", title: "Home"}]
    ]
    |> Enum.reject(&(&1 == []))
  end

  def post_flags(post, config) do
    Enum.zip(post.flag_codes || [], post.flag_alts || [])
    |> Enum.map(fn {code, alt} ->
      %{
        code: code,
        alt: alt,
        src: flag_path(code, config)
      }
    end)
  end

  def state_icons(post, config) do
    []
    |> maybe_add_icon(post.sticky, config.image_sticky, "Important")
    |> maybe_add_icon(post.locked, config.image_locked, "Locked")
    |> maybe_add_icon(post.sage, config.image_bumplocked, "Bumplocked")
    |> maybe_add_icon(post.cycle, config.image_cyclical, "Cyclical")
  end

  def formatted_timestamp(%{inserted_at: %NaiveDateTime{} = inserted_at}) do
    Calendar.strftime(inserted_at, "%m/%d/%y (%a) %H:%M:%S")
  end

  def formatted_timestamp(%{inserted_at: %DateTime{} = inserted_at}) do
    Calendar.strftime(DateTime.to_naive(inserted_at), "%m/%d/%y (%a) %H:%M:%S")
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

  def stored_file_name(file) do
    file
    |> Map.get(:file_path)
    |> case do
      nil -> file_display_name(file)
      path -> Path.basename(path)
    end
  end

  def original_file_name(file) do
    file_display_name(file)
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

  def file_info_details(file, config) do
    parts =
      [human_file_size(file.file_size), dimensions(file), original_file_name_detail(file, config)]
      |> Enum.reject(&is_nil/1)

    Enum.join(parts, ", ")
  end

  def thumb_style(file, config, opts \\ []) do
    op? = Keyword.get(opts, :op?, false)
    max_width = if op?, do: config.thumb_op_width, else: config.thumb_width
    max_height = if op?, do: config.thumb_op_height, else: config.thumb_height

    case fit_dimensions(
           Map.get(file, :image_width),
           Map.get(file, :image_height),
           max_width,
           max_height
         ) do
      {width, height} -> "width:#{width}px;height:#{height}px"
      nil -> nil
    end
  end

  def body_html(post) do
    if post.raw_html, do: post.body, else: post.body
  end

  def omitted_text(summary) do
    parts =
      []
      |> maybe_add_omitted(summary.omitted_posts, "posts")
      |> maybe_add_omitted(summary.omitted_images, "image replies")

    case parts do
      [] -> nil
      values -> Enum.join(values, " and ") <> " omitted. Click reply to view."
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

  defp flag_path(code, config) when is_binary(code) do
    config.uri_flags
    |> String.replace("%s", code)
  end

  defp flag_path(_code, _config), do: nil

  defp maybe_add_icon(icons, true, path, title) when is_binary(path) and path != "" do
    icons ++ [%{path: path, title: title}]
  end

  defp maybe_add_icon(icons, _enabled, _path, _title), do: icons

  defp maybe_add_omitted(parts, count, label) when is_integer(count) and count > 0 do
    parts ++ ["#{count} #{label}"]
  end

  defp maybe_add_omitted(parts, _count, _label), do: parts

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

  defp original_file_name_detail(file, config) do
    original = original_file_name(file)
    stored = stored_file_name(file)
    limit = max(Map.get(config, :max_filename_display_length, 64), 1)

    cond do
      original in [nil, "", stored] ->
        nil

      String.length(original) > limit ->
        String.slice(original, 0, limit) <> "..."

      true ->
        original
    end
  end

  defp fit_dimensions(width, height, max_width, max_height)
       when is_integer(width) and width > 0 and is_integer(height) and height > 0 and
              is_integer(max_width) and max_width > 0 and is_integer(max_height) and
              max_height > 0 do
    scale = min(max_width / width, max_height / height)
    scale = min(scale, 1.0)
    {max(trunc(Float.floor(width * scale)), 1), max(trunc(Float.floor(height * scale)), 1)}
  end

  defp fit_dimensions(_width, _height, _max_width, _max_height), do: nil

  defp normalize_string(nil), do: nil
  defp normalize_string(value) when is_binary(value), do: String.trim(value)

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)
end
