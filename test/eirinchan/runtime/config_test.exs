defmodule Eirinchan.Runtime.ConfigTest do
  use ExUnit.Case, async: true

  alias Eirinchan.Boards.Board
  alias Eirinchan.Runtime.Config

  test "merges default, instance, and board config before applying computed defaults" do
    defaults = %{
      root: "/",
      file_post: "post.php",
      file_index: "index.html",
      file_page: "%d.html",
      file_page50: "%d+50.html",
      file_page_slug: "%d-%s.html",
      file_page50_slug: "%d+50-%s.html",
      file_mod: "mod.php",
      file_script: "main.js",
      board_path: "%s/",
      board_abbreviation: "%s/",
      board_regex: "[a-z]+",
      dir: %{img: "img/", thumb: "thumb/", res: "res/"},
      cookies: %{mod: "mod"},
      user_flag: false,
      multiple_flags: true
    }

    instance = %{
      root: "/chan/",
      dir: %{img: "images/"},
      cookies: %{mod: "__Host-mod"}
    }

    board_overrides = %{
      dir: %{thumb: "th/"},
      file_index: "home.html",
      user_flag: true,
      multiple_flags: true
    }

    board =
      Board.with_runtime_paths(
        %Board{uri: "tech", title: "Technology"},
        Config.compose(defaults, instance)
      )

    config =
      Config.compose(defaults, instance, board_overrides,
        board: board,
        request_host: "example.test"
      )

    assert config.root == "/chan/"
    assert config.file_index == "home.html"
    assert config.post_url == "/chan/post.php"
    assert config.cookies.mod == "__Host-mod"
    assert config.cookies.path == "/chan/"
    assert config.dir.img == "images/"
    assert config.dir.thumb == "th/"
    assert config.uri_thumb == "/chan/tech/th/"
    assert config.uri_img == "/chan/tech/images/"
    assert config.url_stylesheet == "/chan/stylesheets/style.css"
    assert config.url_javascript == "/chan/main.js"
    assert config.default_user_flag == "country"
    assert config.multiple_flags
    assert Regex.match?(config.referer_match, "https://example.test/chan/tech/home.html")

    assert Regex.match?(
             config.referer_match,
             "https://example.test/chan/tech/res/42-thread-slug.html"
           )
  end

  test "disables multiple_flags unless user_flag is enabled" do
    config =
      Config.compose(
        %{
          root: "/",
          user_flag: false,
          multiple_flags: true,
          dir: %{img: "img/", thumb: "thumb/", res: "res/"}
        },
        %{},
        %{}
      )

    refute config.multiple_flags
  end
end
