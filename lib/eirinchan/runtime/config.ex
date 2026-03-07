defmodule Eirinchan.Runtime.Config do
  @moduledoc """
  Builds the effective runtime config with vichan-style precedence:

    * defaults
    * instance overrides
    * board overrides

  Computed defaults are applied after merging, mirroring `loadConfig()`.
  """

  alias Eirinchan.Boards.Board

  @default_config %{
    root: "/",
    root_file: nil,
    file_post: "post.php",
    file_index: "index.html",
    file_board_index: "index.html",
    file_page: "%d.html",
    file_page50: "%d+50.html",
    file_page_slug: "%d-%s.html",
    file_page50_slug: "%d+50-%s.html",
    file_catalog: "catalog.html",
    file_mod: "mod.php",
    file_script: "main.js",
    generation_strategy: "immediate",
    fileboard: false,
    board_path: "%s/",
    board_abbreviation: "%s/",
    board_regex: "[a-zA-Z0-9_]+",
    locale: "en",
    timezone: "UTC",
    anonymous: "Anonymous",
    global_message: false,
    allow_roll: false,
    try_smarter: false,
    board_locked: false,
    strip_combining_chars: false,
    wordfilters: [],
    hidden_input_name: "hash",
    hidden_input_hash: nil,
    antispam_question: false,
    antispam_question_answer: nil,
    flood_time_ip: 0,
    flood_time_same: 0,
    search_enabled: true,
    search_allowed_boards: nil,
    search_disallowed_boards: [],
    search_query_limit_window: 60,
    search_query_limit_count: 0,
    force_body: true,
    force_body_op: true,
    force_image_op: false,
    max_body: 1_800,
    maximum_lines: 100,
    max_images: 1,
    field_disable_name: false,
    field_disable_email: false,
    field_disable_subject: false,
    field_disable_reply_subject: false,
    field_disable_password: false,
    threads_per_page: 10,
    max_pages: 10,
    threads_preview: 5,
    threads_preview_sticky: 1,
    reply_limit: 250,
    reply_hard_limit: 0,
    image_hard_limit: 0,
    cycle_limit: 250,
    always_noko: false,
    slugify: false,
    slug_max_size: 80,
    button_newtopic: "New Topic",
    button_reply: "New Reply",
    allowed_tags: false,
    proxy_save: false,
    country_flags: false,
    allow_no_country: false,
    country_flag_data: %{},
    country_flag_fallback: %{code: "us", name: "United States"},
    country_flag_exclusions: ["eu", "ap", "o1", "a1", "a2"],
    user_flag: false,
    multiple_flags: false,
    default_user_flag: "country",
    user_flags: %{},
    duplicate_file_mode: false,
    max_filesize: 5_000_000,
    multiimage_method: "split",
    max_filename_display_length: 64,
    thumb_width: 250,
    thumb_height: 250,
    thumb_op_width: 250,
    thumb_op_height: 250,
    max_image_width: 0,
    max_image_height: 0,
    file_thumb: nil,
    file_icons: %{},
    minimum_copy_resize: false,
    redraw_image: false,
    strip_exif: false,
    use_exiftool: false,
    auto_orient_images: false,
    upload_by_url_enabled: false,
    upload_by_url_timeout_ms: 5_000,
    allowed_ext_files_op: nil,
    allowed_ext_files: [".png", ".jpg", ".jpeg", ".gif"],
    captcha: %{
      enabled: false,
      provider: "native",
      expected_response: nil,
      mode: "always",
      refresh_on_error: true,
      challenge: nil
    },
    api: %{enabled: false},
    cache: %{enabled: false, ttl_seconds: 0},
    cookies: %{
      mod: "mod",
      js: "serv",
      jail: true,
      expire: 60 * 60 * 24 * 7,
      httponly: true
    },
    dir: %{
      img: "src/",
      thumb: "thumb/",
      res: "res/"
    },
    log_system: %{
      type: "error_log",
      name: "tinyboard",
      syslog_stderr: false,
      file_path: "/var/log/vichan.log"
    },
    error: %{
      bot: "Invalid post action.",
      referer: "Invalid referer.",
      tooshort_body: "Body too short.",
      toolong_body: "The body was too long.",
      toomanylines: "Your post contains too many lines!",
      invalid_flag: "Invalid flag selection.",
      antispam: "Spam filter triggered.",
      captcha: "Captcha validation failed.",
      banned: "You are banned.",
      locked: "Thread locked. You may not reply at this time.",
      reply_hard_limit: "Thread has reached its maximum reply limit.",
      image_hard_limit: "Thread has reached its maximum image limit.",
      board_locked: "Board is locked.",
      password: "Incorrect password.",
      duplicate_file: "Duplicate file.",
      file_required: "File required.",
      filetype: "File type not allowed.",
      invalid_image: "Invalid image.",
      image_too_large: "Image dimensions too large.",
      file_too_large: "File too large.",
      upload_failed: "Upload failed."
    }
  }

  @type t :: map()

  @spec default_config() :: t()
  def default_config, do: @default_config

  @spec compose(map() | nil, map(), map(), keyword()) :: t()
  def compose(defaults \\ nil, instance_overrides \\ %{}, board_overrides \\ %{}, opts \\ []) do
    base_defaults = deep_merge(default_config(), defaults || %{})
    board = Keyword.get(opts, :board)
    request_host = Keyword.get(opts, :request_host)

    base_defaults
    |> deep_merge(instance_overrides)
    |> deep_merge(board_overrides)
    |> apply_computed_defaults(board, request_host)
  end

  @spec deep_merge(map(), map()) :: map()
  def deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_value, right_value ->
      if is_map(left_value) and is_map(right_value) do
        deep_merge(left_value, right_value)
      else
        right_value
      end
    end)
  end

  defp apply_computed_defaults(config, board, request_host) do
    config
    |> Map.put_new(:global_message, false)
    |> Map.put_new(:post_url, path_join(config.root, config.file_post))
    |> put_nested_new([:cookies, :path], config.root)
    |> normalize_cookie_names()
    |> Map.put_new(:referer_match, build_referer_match(config, request_host))
    |> ensure_web_assets()
    |> ensure_static_assets()
    |> apply_board_paths(board)
    |> normalize_flags()
  end

  defp ensure_web_assets(config) do
    config
    |> Map.put_new(:uri_stylesheets, path_join(config.root, "stylesheets/"))
    |> then(fn updated ->
      updated
      |> Map.put_new(:url_stylesheet, path_join(updated.uri_stylesheets, "style.css"))
      |> Map.put_new(:url_javascript, path_join(updated.root, updated.file_script))
      |> Map.put_new(:additional_javascript_url, updated.root)
      |> Map.put_new(:uri_flags, path_join(updated.root, "static/flags/%s.png"))
    end)
  end

  defp ensure_static_assets(config) do
    static_dir = Map.get(config.dir, :static, path_join(config.root, "static/"))
    dir = Map.put(config.dir, :static, static_dir)

    config
    |> Map.put(:dir, dir)
    |> Map.put_new(:image_blank, path_join(static_dir, "blank.gif"))
    |> Map.put_new(:image_sticky, path_join(static_dir, "sticky.gif"))
    |> Map.put_new(:image_locked, path_join(static_dir, "locked.gif"))
    |> Map.put_new(:image_bumplocked, path_join(static_dir, "sage.gif"))
    |> Map.put_new(:image_deleted, path_join(static_dir, "deleted.png"))
    |> Map.put_new(:image_cyclical, path_join(static_dir, "cycle.png"))
  end

  defp apply_board_paths(config, nil), do: config

  defp apply_board_paths(config, %Board{} = board) do
    config
    |> Map.put_new(:uri_thumb, board_asset_path(config, board.dir, config.dir.thumb))
    |> Map.put_new(:uri_img, board_asset_path(config, board.dir, config.dir.img))
  end

  defp normalize_flags(config) do
    config =
      config
      |> Map.put_new(:user_flag, false)
      |> Map.put_new(:multiple_flags, false)
      |> Map.put_new(:default_user_flag, "country")
      |> Map.put_new(:user_flags, %{})
      |> normalize_captcha()

    normalized_default =
      normalize_default_user_flag(config.default_user_flag, config.multiple_flags)

    if config.user_flag do
      %{config | default_user_flag: normalized_default}
    else
      %{config | default_user_flag: normalized_default, multiple_flags: false}
    end
  end

  defp normalize_captcha(config) do
    captcha =
      config
      |> Map.get(:captcha, %{})
      |> Map.put_new(:enabled, false)
      |> Map.put_new(:provider, "native")
      |> Map.put_new(:expected_response, nil)
      |> Map.put_new(:mode, "always")
      |> Map.put_new(:refresh_on_error, true)
      |> Map.put_new(:challenge, nil)
      |> Map.update!(:mode, fn mode ->
        mode
        |> to_string()
        |> String.trim()
        |> String.downcase()
        |> case do
          "op" -> "op"
          "reply" -> "reply"
          "none" -> "none"
          _ -> "always"
        end
      end)

    Map.put(config, :captcha, captcha)
  end

  defp normalize_default_user_flag(default_user_flag, true) do
    default_user_flag
    |> to_string()
    |> String.split(",", trim: false)
    |> Enum.map(&(String.trim(&1) |> String.downcase()))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(",")
    |> case do
      "" -> "country"
      value -> value
    end
  end

  defp normalize_default_user_flag(default_user_flag, false) do
    default_user_flag
    |> to_string()
    |> String.trim()
    |> String.downcase()
    |> case do
      "" -> "country"
      value -> value
    end
  end

  defp normalize_cookie_names(config) do
    cookie_name =
      case {get_in(config, [:cookies, :jail]), get_in(config, [:cookies, :mod]), config.root} do
        {true, name, "/"} -> "__Host-" <> String.trim_leading(to_string(name), "__Host-")
        {true, name, _root} -> "__Secure-" <> String.trim_leading(to_string(name), "__Secure-")
        {_jail, name, _root} -> to_string(name)
      end

    put_nested_new(config, [:cookies, :mod_cookie_name], cookie_name)
  end

  defp put_nested_new(config, [key], value), do: Map.put_new(config, key, value)

  defp put_nested_new(config, [key | rest], value) do
    nested =
      config
      |> Map.get(key, %{})
      |> put_nested_new(rest, value)

    Map.put(config, key, nested)
  end

  defp build_referer_match(_config, nil), do: ~r//

  defp build_referer_match(config, request_host) do
    prefix =
      if String.match?(config.root, ~r/^https?:\/\//) do
        ""
      else
        "https?:\\/\\/#{Regex.escape(request_host)}"
      end

    board_path = interpolate_path_pattern(config.board_path, config.board_regex)
    res_path = Regex.escape(config.dir.res)
    file_index = Regex.escape(config.file_index)
    file_page = interpolate_integer_pattern(config.file_page)
    file_page50 = interpolate_integer_pattern(config.file_page50)
    file_page_slug = interpolate_thread_slug_pattern(config.file_page_slug)
    file_page50_slug = interpolate_thread_slug_pattern(config.file_page50_slug)
    mod_path = Regex.escape(config.file_mod)

    Regex.compile!(
      "^" <>
        prefix <>
        Regex.escape(config.root) <>
        "(" <>
        board_path <>
        "(#{file_index}|#{file_page})?" <>
        "|" <>
        board_path <>
        res_path <>
        "(#{file_page}|#{file_page50}|#{file_page_slug}|#{file_page50_slug})" <>
        "|" <>
        mod_path <>
        "\\?/.*" <>
        ")([#?](.+)?)?$",
      "ui"
    )
  end

  defp interpolate_path_pattern(template, board_regex) do
    template
    |> Regex.escape()
    |> String.replace("%s", board_regex)
  end

  defp interpolate_integer_pattern(template) do
    template
    |> Regex.escape()
    |> String.replace("%d", "\\d+")
  end

  defp interpolate_thread_slug_pattern(template) do
    template
    |> Regex.escape()
    |> String.replace("%d", "\\d+")
    |> String.replace("%s", "[a-z0-9-]+")
  end

  defp board_asset_path(config, board_dir, suffix) do
    path_join(config.root, board_dir, suffix)
  end

  defp path_join(left, right), do: path_join(left, nil, right)

  defp path_join(left, middle, right) when is_binary(left) do
    if String.starts_with?(left, ["http://", "https://"]) do
      uri = URI.parse(left)
      path = path_join(uri.path || "/", middle, right)
      %{uri | path: path} |> URI.to_string()
    else
      join_relative_path(left, middle, right)
    end
  end

  defp path_join(left, middle, right) do
    join_relative_path(left, middle, right)
  end

  defp join_relative_path(left, middle, right) do
    preserve_trailing_slash? =
      [right, middle, left]
      |> Enum.reject(&is_nil/1)
      |> List.first()
      |> to_string()
      |> String.ends_with?("/")

    [left, middle, right]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&trim_path_segment/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> "/"
      segments -> join_segments(segments, left, preserve_trailing_slash?)
    end
  end

  defp trim_path_segment(segment) do
    segment
    |> to_string()
    |> String.trim()
    |> String.trim("/")
  end

  defp join_segments(segments, original_left, preserve_trailing_slash?) do
    joined = Enum.join(segments, "/")

    base =
      cond do
        String.starts_with?(to_string(original_left), "/") ->
          "/" <> joined

        true ->
          joined
      end

    if preserve_trailing_slash?, do: base <> "/", else: base
  end
end
