defmodule EirinchanWeb.PostView do
  @moduledoc false

  import Phoenix.HTML, only: [html_escape: 1, safe_to_string: 1]

  alias Eirinchan.Boardlist
  alias Eirinchan.Posts.PostFile
  alias Eirinchan.Themes
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
    Boardlist.configured_groups(boards)
  end

  def default_boardlist_groups(boards) do
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

  def boardlist_html(groups, class_name \\ "boardlist") do
    spans =
      Enum.map_join(groups, "  ", fn group ->
        links = group[:links] || group

        description_attr =
          if group[:description], do: ~s( data-description="#{group[:description]}"), else: ""

        links_html =
          Enum.map_join(links, " / ", fn link ->
            ~s(<a href="#{html_escape_to_string(link.href)}" title="#{html_escape_to_string(link.title)}">#{html_escape_to_string(link.label)}</a>)
          end)

        ~s(<span class="sub"#{description_attr}>[ #{links_html} ]</span>)
      end)

    ~s(<div class="#{class_name}">#{spans}</div>)
  end

  def pages_html(page_data, board_uri) do
    previous_html =
      if page_data.page > 1 do
        previous = Enum.at(page_data.pages, page_data.page - 2)
        ~s(<a href="#{html_escape_to_string(previous.link)}">Previous</a>)
      else
        "Previous"
      end

    page_links =
      Enum.map_join(page_data.pages, " ", fn page ->
        if page.num == page_data.page do
          ~s([<a class="selected">#{page.num}</a>])
        else
          ~s([<a href="#{html_escape_to_string(page.link)}">#{page.num}</a>])
        end
      end)

    next_html =
      if page_data.page < page_data.total_pages do
        next = Enum.at(page_data.pages, page_data.page)

        ~s(<form action="#{html_escape_to_string(next.link)}" method="get"><input type="submit" value="Next" /></form>)
      else
        ""
      end

    catalog_link =
      if Themes.page_theme_enabled?("catalog"),
        do: ~s( | <a href="/#{board_uri}/catalog.html">Catalog</a>),
        else: ""

    ~s(<div class="pages">#{previous_html}  #{page_links}#{if next_html != "", do: "  " <> next_html, else: ""}#{catalog_link}</div>)
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

  def iso_timestamp(%{inserted_at: %DateTime{} = inserted_at}),
    do: DateTime.to_iso8601(inserted_at)

  def iso_timestamp(%{inserted_at: %NaiveDateTime{} = inserted_at}),
    do: NaiveDateTime.to_iso8601(inserted_at)

  def iso_timestamp(_post), do: nil

  def unix_timestamp(%DateTime{} = value), do: DateTime.to_unix(value)

  def unix_timestamp(%NaiveDateTime{} = value),
    do: value |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

  def unix_timestamp(_value), do: 0

  def file_size_text(file), do: human_file_size(Map.get(file, :file_size))
  def file_dimensions(file), do: dimensions(file)
  def file_class(post), do: if(length(all_files(post)) > 1, do: "file multifile", else: "file")
  def post_container_style(post), do: if(length(all_files(post)) > 1, do: "clear:both", else: nil)
  def reply_body_style(reply), do: if(length(all_files(reply)) > 1, do: "clear:both", else: nil)

  def catalog_label(post, config) do
    cond do
      present?(post.subject) -> post.subject
      config.fileboard && present?(post.file_name) -> post.file_name
      true -> nil
    end
  end

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

  def display_file_name(file, config) do
    original = original_file_name(file)
    limit = max(Map.get(config, :max_filename_display_length, 30), 1)

    cond do
      original in [nil, ""] ->
        original

      String.length(original) <= limit ->
        original

      true ->
        ext = Path.extname(original)
        base = Path.rootname(original, ext)
        suffix = "…" <> ext
        keep = max(limit - String.length(suffix), 1)
        String.slice(base, 0, keep) <> suffix
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

  def multifile_style(file, config, opts \\ []) do
    if Keyword.get(opts, :multifile, false) do
      case fit_dimensions(
             Map.get(file, :image_width),
             Map.get(file, :image_height),
             config.thumb_width,
             config.thumb_height
           ) do
        {width, _height} -> "width:#{width + 40}px"
        nil -> nil
      end
    else
      nil
    end
  end

  def body_html(post, board, thread, config) do
    if post.raw_html do
      post.body || ""
    else
      post.body
      |> Kernel.||("")
      |> html_escape()
      |> safe_to_string()
      |> String.split("\n", trim: false)
      |> Enum.map(&format_body_line(&1, board, thread, config))
      |> Enum.join("<br/>")
    end
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

  defp format_body_line(line, board, thread, config) do
    rendered = render_quote_links(line, board, thread, config)

    if String.starts_with?(rendered, "&gt;") and not String.starts_with?(rendered, "&gt;&gt;") do
      ~s(<span class="quote">#{rendered}</span>)
    else
      rendered
    end
  end

  defp render_quote_links(line, board, thread, config) do
    Regex.replace(~r/&gt;&gt;(\d+)/, line, fn _match, id ->
      href = ThreadPaths.thread_path(board, thread, config) <> "##{id}"
      "<a onclick=\"highlightReply('#{id}', event);\" href=\"#{href}\">&gt;&gt;#{id}</a>"
    end)
  end

  defp html_escape_to_string(value) do
    value
    |> to_string()
    |> html_escape()
    |> safe_to_string()
  end

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
    limit = max(Map.get(config, :max_filename_display_length, 30), 1)

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
