defmodule Eirinchan.TestFailingPostFileRepo do
  alias Eirinchan.Posts.PostFile
  alias Eirinchan.Repo

  def transaction(fun), do: Repo.transaction(fun)
  def rollback(reason), do: Repo.rollback(reason)
  def update(changeset), do: Repo.update(changeset)
  def all(queryable), do: Repo.all(queryable)
  def one(queryable), do: Repo.one(queryable)
  def aggregate(queryable, aggregate, field), do: Repo.aggregate(queryable, aggregate, field)
  def exists?(queryable), do: Repo.exists?(queryable)
  def preload(struct_or_structs, preloads), do: Repo.preload(struct_or_structs, preloads)
  def get_by(queryable, clauses), do: Repo.get_by(queryable, clauses)
  def delete(struct), do: Repo.delete(struct)

  def insert(%Ecto.Changeset{data: %PostFile{}} = changeset) do
    if Process.get(:fail_post_file_insert_once) do
      Process.delete(:fail_post_file_insert_once)
      {:error, Ecto.Changeset.add_error(changeset, :position, "forced failure")}
    else
      Repo.insert(changeset)
    end
  end

  def insert(changeset), do: Repo.insert(changeset)
end

defmodule Eirinchan.PostsTest do
  use Eirinchan.DataCase, async: true

  alias Eirinchan.Posts
  alias Eirinchan.Posts.Post
  alias Eirinchan.Runtime.Config

  defp post_config(board_overrides) do
    Config.compose(nil, %{}, board_overrides, request_host: "example.test")
  end

  defp post_request(board_uri) do
    %{referer: "http://example.test/#{board_uri}/index.html"}
  end

  defp exiftool_value(path, field) do
    {output, 0} = System.cmd("exiftool", ["-s3", "-#{field}", path], stderr_to_stdout: true)
    String.trim(output)
  end

  defp identify_value(path, format) do
    {output, 0} = System.cmd("identify", ["-format", format, path], stderr_to_stdout: true)
    String.trim(output)
  end

  test "create_post creates an OP when no thread is supplied" do
    board = board_fixture()

    assert {:ok, thread, %{noko: false}} =
             Posts.create_post(
               board,
               %{
                 "name" => " anon ",
                 "subject" => " launch ",
                 "body" => "  first post  ",
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    assert thread.thread_id == nil
    assert thread.name == "anon"
    assert thread.subject == "launch"
    assert thread.body == "first post"
  end

  test "create_post creates a reply when a valid thread is supplied" do
    board = board_fixture()
    thread = thread_fixture(board)

    assert {:ok, reply, %{noko: false}} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "reply body",
                 "post" => "New Reply"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    assert reply.thread_id == thread.id
  end

  test "create_post stores upload metadata for image posts" do
    board = board_fixture()
    upload = upload_fixture("first.png", "png-bytes")
    upload_size = File.stat!(upload.path).size

    assert {:ok, thread, %{noko: false}} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "file" => upload,
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    assert thread.file_name == "first.png"
    assert thread.file_path == "/#{board.uri}/src/#{thread.id}.png"
    assert thread.thumb_path == "/#{board.uri}/thumb/#{thread.id}s.png"
    assert thread.file_size == upload_size
    assert thread.file_type == "image/png"
    assert is_binary(thread.file_md5)
    assert thread.image_width == 16
    assert thread.image_height == 16

    assert File.exists?(
             Path.join(Eirinchan.Build.board_root(), "#{board.uri}/src/#{thread.id}.png")
           )

    assert File.exists?(
             Path.join(Eirinchan.Build.board_root(), "#{board.uri}/thumb/#{thread.id}s.png")
           )
  end

  test "create_post stores placeholder thumbnails for allowed non-image uploads" do
    board =
      board_fixture(%{
        config_overrides: %{allowed_ext_files: [".png", ".jpg", ".jpeg", ".gif", ".txt"]}
      })

    upload = raw_upload_fixture("notes.txt", "hello")

    assert {:ok, thread, %{noko: false}} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "file" => upload,
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    assert thread.file_name == "notes.txt"
    assert thread.file_path == "/#{board.uri}/src/#{thread.id}.txt"
    assert thread.thumb_path == "/#{board.uri}/thumb/#{thread.id}s.png"
    assert thread.file_size == byte_size("hello")
    assert thread.file_type == "text/plain"
    assert thread.image_width == nil
    assert thread.image_height == nil
    assert File.exists?(Eirinchan.Uploads.filesystem_path(thread.file_path))
    assert File.exists?(Eirinchan.Uploads.filesystem_path(thread.thumb_path))
  end

  test "create_post stores extra files from a multi-file upload" do
    board = board_fixture()

    assert {:ok, thread, %{noko: false}} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "files" => [
                   upload_fixture("first.png", "first"),
                   upload_fixture("second.gif", "second")
                 ],
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    assert thread.file_name == "first.png"
    assert length(thread.extra_files) == 1

    [extra] = thread.extra_files
    assert extra.position == 1
    assert extra.file_name == "second.gif"
    assert extra.file_path == "/#{board.uri}/src/#{thread.id}-1.gif"
    assert extra.thumb_path == "/#{board.uri}/thumb/#{thread.id}-1s.png"
  end

  test "create_post marks spoiler uploads on primary and extra files" do
    board = board_fixture()

    assert {:ok, thread, %{noko: false}} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "files" => [
                   upload_fixture("first.png", "first"),
                   upload_fixture("second.gif", "second")
                 ],
                 "spoiler" => "1",
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    assert thread.spoiler == true
    assert [extra] = thread.extra_files
    assert extra.spoiler == true
    assert File.exists?(Eirinchan.Uploads.filesystem_path(thread.thumb_path))
    assert File.exists?(Eirinchan.Uploads.filesystem_path(extra.thumb_path))
  end

  test "create_post supports OP-specific extension allowlists" do
    board =
      board_fixture(%{
        config_overrides: %{allowed_ext_files: [".png", ".jpg"], allowed_ext_files_op: [".txt"]}
      })

    config = post_config(board.config_overrides)
    request = post_request(board.uri)

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Opening body",
                 "file" => raw_upload_fixture("notes.txt", "hello"),
                 "post" => "New Topic"
               },
               config: config,
               request: request
             )

    assert thread.file_type == "text/plain"

    assert {:error, :invalid_file_type} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "Reply body",
                 "file" => raw_upload_fixture("reply.txt", "hello"),
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )
  end

  test "create_post rejects extension-spoofed non-image uploads" do
    board =
      board_fixture(%{
        config_overrides: %{allowed_ext_files: [".png", ".jpg", ".jpeg", ".gif", ".txt"]}
      })

    spoofed_upload =
      duplicate_upload_fixture(upload_fixture("real.png", "png-bytes"), "notes.txt")

    assert {:error, :invalid_file_type} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "file" => spoofed_upload,
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )
  end

  test "create_post canonicalizes and truncates stored filenames" do
    board = board_fixture(%{config_overrides: %{max_filename_display_length: 12}})

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "file" =>
                   upload_fixture(
                     "  a very long*&^% display filename with spaces.PNG  ",
                     "png-bytes"
                   ),
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    assert thread.file_name == "a_very_long_.png"
  end

  test "create_post strips EXIF metadata from stored jpeg files when configured" do
    board = board_fixture(%{config_overrides: %{strip_exif: true}})
    upload = upload_fixture("meta.jpg", geometry: "10x10", artist: "fixture-artist")

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "file" => upload,
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    stored_path = Eirinchan.Uploads.filesystem_path(thread.file_path)

    assert exiftool_value(stored_path, "Artist") == ""
  end

  test "create_post copies small png files directly into thumbnails when minimum_copy_resize is enabled" do
    board = board_fixture(%{config_overrides: %{minimum_copy_resize: true}})
    upload = upload_fixture("small.png", geometry: "12x8")

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "file" => upload,
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    stored_path = Eirinchan.Uploads.filesystem_path(thread.file_path)
    thumb_path = Eirinchan.Uploads.filesystem_path(thread.thumb_path)

    assert File.read!(stored_path) == File.read!(thumb_path)
    assert identify_value(thumb_path, "%wx%h") == "12x8"
  end

  test "create_post auto-orients stored jpeg files and refreshes dimensions" do
    board = board_fixture(%{config_overrides: %{auto_orient_images: true}})

    upload = upload_fixture("rotated.jpg", geometry: "12x8", orientation: "Rotate 90 CW")

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "file" => upload,
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    stored_path = Eirinchan.Uploads.filesystem_path(thread.file_path)

    assert {thread.image_width, thread.image_height} == {8, 12}
    assert identify_value(stored_path, "%wx%h") == "8x12"
    assert exiftool_value(stored_path, "Orientation") == "Horizontal (normal)"
  end

  test "create_post redraws stored images when redraw_image is enabled" do
    board = board_fixture(%{config_overrides: %{redraw_image: true}})

    upload =
      upload_fixture("redrawn.jpg",
        geometry: "12x8",
        orientation: "Rotate 90 CW",
        artist: "fixture-artist"
      )

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "file" => upload,
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    stored_path = Eirinchan.Uploads.filesystem_path(thread.file_path)

    assert {thread.image_width, thread.image_height} == {8, 12}
    assert identify_value(stored_path, "%wx%h") == "8x12"
    assert exiftool_value(stored_path, "Artist") == ""
    assert exiftool_value(stored_path, "Orientation") == ""
  end

  test "create_post strips jpeg metadata with exiftool without redrawing by default" do
    board = board_fixture(%{config_overrides: %{strip_exif: true, use_exiftool: true}})

    upload =
      upload_fixture("exiftool.jpg",
        geometry: "12x8",
        orientation: "Rotate 90 CW",
        artist: "fixture-artist"
      )

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "file" => upload,
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    stored_path = Eirinchan.Uploads.filesystem_path(thread.file_path)

    assert {thread.image_width, thread.image_height} == {12, 8}
    assert identify_value(stored_path, "%wx%h") == "12x8"
    assert exiftool_value(stored_path, "Artist") == ""
    assert exiftool_value(stored_path, "Orientation") == ""
  end

  test "create_post can auto-orient before exiftool stripping" do
    board =
      board_fixture(%{
        config_overrides: %{strip_exif: true, use_exiftool: true, auto_orient_images: true}
      })

    upload =
      upload_fixture("exiftool-oriented.jpg",
        geometry: "12x8",
        orientation: "Rotate 90 CW",
        artist: "fixture-artist"
      )

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "file" => upload,
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    stored_path = Eirinchan.Uploads.filesystem_path(thread.file_path)

    assert {thread.image_width, thread.image_height} == {8, 12}
    assert identify_value(stored_path, "%wx%h") == "8x12"
    assert exiftool_value(stored_path, "Artist") == ""
    assert exiftool_value(stored_path, "Orientation") == ""
  end

  test "create_post auto-orients images before stripping EXIF when both are enabled" do
    board = board_fixture(%{config_overrides: %{auto_orient_images: true, strip_exif: true}})

    upload =
      upload_fixture("rotated.jpg",
        geometry: "12x8",
        orientation: "Rotate 90 CW",
        artist: "fixture-artist"
      )

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "file" => upload,
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    stored_path = Eirinchan.Uploads.filesystem_path(thread.file_path)

    assert {thread.image_width, thread.image_height} == {8, 12}
    assert identify_value(stored_path, "%wx%h") == "8x12"
    assert exiftool_value(stored_path, "Artist") == ""
    assert exiftool_value(stored_path, "Orientation") == ""
  end

  test "create_post fetches remote uploads when url uploads are enabled" do
    board = board_fixture(%{config_overrides: %{upload_by_url_enabled: true}})
    source_upload = upload_fixture("remote.png", "remote-image")
    server = serve_upload_fixture(File.read!(source_upload.path), "remote.png")
    on_exit(server.stop)

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "file_url" => server.url,
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    assert thread.file_name == "remote.png"
    assert thread.file_type == "image/png"
    assert File.exists?(Eirinchan.Uploads.filesystem_path(thread.file_path))
  end

  test "create_post removes stored files when a later file insert fails" do
    File.rm_rf!(Eirinchan.Build.board_root())

    board = board_fixture()
    Process.put(:fail_post_file_insert_once, true)

    assert {:error, %Ecto.Changeset{}} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "files" => [
                   upload_fixture("first.png", "first"),
                   upload_fixture("second.gif", "second")
                 ],
                 "post" => "New Topic"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri),
               repo: Eirinchan.TestFailingPostFileRepo
             )

    refute Repo.exists?(from post in Post, where: post.board_id == ^board.id)
    assert Path.wildcard(Path.join(Eirinchan.Build.board_root(), "#{board.uri}/src/*")) == []
    assert Path.wildcard(Path.join(Eirinchan.Build.board_root(), "#{board.uri}/thumb/*")) == []
  end

  test "create_post rejects replies to missing threads" do
    board = board_fixture()

    assert {:error, :thread_not_found} =
             Posts.create_post(
               board,
               %{
                 "thread" => "999999",
                 "body" => "reply body",
                 "post" => "New Reply"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )
  end

  test "create_post rejects an invalid referer" do
    board = board_fixture()

    assert {:error, :invalid_referer} =
             Posts.create_post(board, %{"body" => "first post", "post" => "New Topic"},
               config: post_config(board.config_overrides),
               request: %{referer: "http://bad.example/elsewhere"}
             )
  end

  test "create_post enforces board lock and body requirements from config" do
    board = board_fixture(%{config_overrides: %{board_locked: true, force_body_op: true}})

    assert {:error, :board_locked} =
             Posts.create_post(board, %{"body" => "first post", "post" => "New Topic"},
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    unlocked = %{board | config_overrides: %{force_body_op: true}}

    assert {:error, :body_required} =
             Posts.create_post(unlocked, %{"body" => "   ", "post" => "New Topic"},
               config: post_config(unlocked.config_overrides),
               request: post_request(board.uri)
             )
  end

  test "create_post enforces required OP files and upload validation" do
    board = board_fixture(%{config_overrides: %{force_image_op: true}})
    config = post_config(board.config_overrides)

    assert {:error, :file_required} =
             Posts.create_post(board, %{"body" => "first post", "post" => "New Topic"},
               config: config,
               request: post_request(board.uri)
             )

    assert {:error, :invalid_file_type} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "file" => upload_fixture("bad.txt", "bad"),
                 "post" => "New Topic"
               },
               config: config,
               request: post_request(board.uri)
             )

    assert {:error, :invalid_image} =
             Posts.create_post(
               board,
               %{
                 "body" => "first post",
                 "file" => raw_upload_fixture("fake.png", "not-an-image"),
                 "post" => "New Topic"
               },
               config: config,
               request: post_request(board.uri)
             )

    oversized_board = board_fixture(%{config_overrides: %{max_filesize: 1}})

    assert {:error, :file_too_large} =
             Posts.create_post(
               oversized_board,
               %{
                 "body" => "first post",
                 "file" => upload_fixture("big.png", "12345"),
                 "post" => "New Topic"
               },
               config: post_config(oversized_board.config_overrides),
               request: post_request(oversized_board.uri)
             )

    oversized_dimensions_board =
      board_fixture(%{config_overrides: %{max_image_width: 8, max_image_height: 8}})

    assert {:error, :image_too_large} =
             Posts.create_post(
               oversized_dimensions_board,
               %{
                 "body" => "first post",
                 "file" => upload_fixture("wide.png", geometry: "12x9"),
                 "post" => "New Topic"
               },
               config: post_config(oversized_dimensions_board.config_overrides),
               request: post_request(oversized_dimensions_board.uri)
             )
  end

  test "create_post enforces reply hard limits" do
    board = board_fixture(%{config_overrides: %{reply_hard_limit: 1}})
    thread = thread_fixture(board)

    assert {:ok, _reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "first reply",
                 "post" => "New Reply"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )

    assert {:error, :reply_hard_limit} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "second reply",
                 "post" => "New Reply"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )
  end

  test "create_post enforces image hard limits for file replies" do
    board = board_fixture(%{config_overrides: %{image_hard_limit: 1}})
    config = post_config(board.config_overrides)
    request = post_request(board.uri)

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Opening body",
                 "file" => upload_fixture("thread.png", "thread"),
                 "post" => "New Topic"
               },
               config: config,
               request: request
             )

    assert {:error, :image_hard_limit} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "Reply body",
                 "file" => upload_fixture("reply.png", "reply"),
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, _reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "Text-only reply",
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )
  end

  test "create_post rejects duplicate files globally when configured" do
    board = board_fixture(%{config_overrides: %{duplicate_file_mode: "global"}})
    config = post_config(board.config_overrides)
    request = post_request(board.uri)
    upload = upload_fixture("first.png", "same-bytes")

    assert {:ok, _thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Opening body",
                 "file" => upload,
                 "post" => "New Topic"
               },
               config: config,
               request: request
             )

    assert {:error, :duplicate_file} =
             Posts.create_post(
               board,
               %{
                 "body" => "Second body",
                 "file" => duplicate_upload_fixture(upload, "second.png"),
                 "post" => "New Topic"
               },
               config: config,
               request: request
             )
  end

  test "create_post rejects duplicate files within a thread when configured" do
    board = board_fixture(%{config_overrides: %{duplicate_file_mode: "thread"}})
    config = post_config(board.config_overrides)
    request = post_request(board.uri)
    upload = upload_fixture("first.png", "thread-bytes")

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Opening body",
                 "file" => upload,
                 "post" => "New Topic"
               },
               config: config,
               request: request
             )

    assert {:error, :duplicate_file} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "Reply body",
                 "file" => duplicate_upload_fixture(upload, "reply.png"),
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    other_board = board_fixture(%{config_overrides: %{duplicate_file_mode: "thread"}})
    other_upload = duplicate_upload_fixture(upload, "other.png")

    assert {:ok, _other_thread, _meta} =
             Posts.create_post(
               other_board,
               %{
                 "body" => "Other body",
                 "file" => other_upload,
                 "post" => "New Topic"
               },
               config: post_config(other_board.config_overrides),
               request: post_request(other_board.uri)
             )
  end

  test "create_post rejects replies to locked threads" do
    board = board_fixture()
    thread = thread_fixture(board)

    Repo.update_all(
      from(post in Eirinchan.Posts.Post, where: post.id == ^thread.id),
      set: [locked: true]
    )

    assert {:error, :thread_locked} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "Reply body",
                 "post" => "New Reply"
               },
               config: post_config(board.config_overrides),
               request: post_request(board.uri)
             )
  end

  test "reply bumping reorders threads unless the reply is sage" do
    board = board_fixture()
    config = post_config(board.config_overrides)
    request = post_request(board.uri)

    assert {:ok, older_thread, _meta} =
             Posts.create_post(
               board,
               %{"body" => "Older", "subject" => "Older", "post" => "New Topic"},
               config: config,
               request: request
             )

    Process.sleep(1000)

    assert {:ok, newer_thread, _meta} =
             Posts.create_post(
               board,
               %{"body" => "Newer", "subject" => "Newer", "post" => "New Topic"},
               config: config,
               request: request
             )

    assert {:ok, _reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(older_thread.id),
                 "body" => "Bumping reply",
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, page_after_bump} = Posts.list_threads_page(board, 1, config: config)
    assert hd(page_after_bump.threads).thread.id == older_thread.id

    assert {:ok, _reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(newer_thread.id),
                 "body" => "Sage reply",
                 "email" => "sage",
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, page_after_sage} = Posts.list_threads_page(board, 1, config: config)
    assert hd(page_after_sage.threads).thread.id == older_thread.id
  end

  test "find_thread_page tracks bump ordering and slug thread ids" do
    board = board_fixture(%{config_overrides: %{threads_per_page: 1, slugify: true}})
    config = post_config(board.config_overrides)
    request = post_request(board.uri)

    assert {:ok, older_thread, _meta} =
             Posts.create_post(
               board,
               %{"body" => "Older body", "subject" => "Older subject", "post" => "New Topic"},
               config: config,
               request: request
             )

    assert {:ok, newer_thread, _meta} =
             Posts.create_post(
               board,
               %{"body" => "Newer body", "subject" => "Newer subject", "post" => "New Topic"},
               config: config,
               request: request
             )

    assert {:ok, _reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(older_thread.id),
                 "body" => "Bumping reply",
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, 1} = Posts.find_thread_page(board, older_thread.id, config: config)

    assert {:ok, 2} =
             Posts.find_thread_page(board, "#{newer_thread.id}-newer-subject.html", config: config)

    assert {:ok, [thread | _]} =
             Posts.get_thread(board, "#{older_thread.id}-older-subject.html", config: config)

    assert thread.id == older_thread.id
  end

  test "update_thread_state applies cycle and bumplock behavior to future replies" do
    board = board_fixture(%{config_overrides: %{cycle_limit: 1, threads_per_page: 1}})
    config = post_config(board.config_overrides)
    request = post_request(board.uri)

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{"body" => "Opening body", "subject" => "Opening", "post" => "New Topic"},
               config: config,
               request: request
             )

    initial_bump_at = thread.bump_at

    assert {:ok, updated_thread} =
             Posts.update_thread_state(
               board,
               thread.id,
               %{"cycle" => "true", "sage" => "true"},
               config: config
             )

    assert updated_thread.cycle
    assert updated_thread.sage

    assert {:ok, first_reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "First reply",
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, second_reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "Second reply",
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, [reloaded_thread | replies]} = Posts.get_thread(board, thread.id, config: config)
    assert reloaded_thread.bump_at == initial_bump_at
    assert Enum.map(replies, & &1.id) == [second_reply.id]
    refute Enum.any?(replies, &(&1.id == first_reply.id))
  end

  test "delete_post removes replies when the password matches" do
    board = board_fixture()
    config = post_config(board.config_overrides)
    request = post_request(board.uri)

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Opening body",
                 "subject" => "Opening",
                 "password" => "threadpw",
                 "post" => "New Topic"
               },
               config: config,
               request: request
             )

    assert {:ok, reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "Reply body",
                 "password" => "replypw",
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:error, :invalid_password} =
             Posts.delete_post(board, reply.id, "wrong", config: config)

    assert {:ok, %{deleted_post_id: deleted_post_id, thread_id: thread_id, thread_deleted: false}} =
             Posts.delete_post(board, reply.id, "replypw", config: config)

    assert deleted_post_id == reply.id
    assert thread_id == thread.id
    assert {:ok, [reloaded_thread]} = Posts.get_thread(board, thread.id, config: config)
    assert reloaded_thread.id == thread.id
  end

  test "delete_post removes threads and cascades replies when the password matches" do
    board = board_fixture()
    config = post_config(board.config_overrides)
    request = post_request(board.uri)

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Opening body",
                 "subject" => "Opening",
                 "password" => "threadpw",
                 "post" => "New Topic"
               },
               config: config,
               request: request
             )

    assert {:ok, _reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "Reply body",
                 "password" => "replypw",
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, %{deleted_post_id: deleted_post_id, thread_id: thread_id, thread_deleted: true}} =
             Posts.delete_post(board, thread.id, "threadpw", config: config)

    assert deleted_post_id == thread.id
    assert thread_id == thread.id
    assert {:error, :not_found} = Posts.get_thread(board, thread.id, config: config)
    assert Posts.list_threads(board, config: config) == []
  end

  test "list_threads_page returns previews, omitted counts, and page metadata" do
    board = board_fixture(%{config_overrides: %{threads_per_page: 1, threads_preview: 1}})
    config = post_config(board.config_overrides)
    request = post_request(board.uri)

    assert {:ok, older_thread, _meta} =
             Posts.create_post(
               board,
               %{"body" => "Older body", "subject" => "Older", "post" => "New Topic"},
               config: config,
               request: request
             )

    assert {:ok, _reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(older_thread.id),
                 "body" => "Reply one",
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, _reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(older_thread.id),
                 "body" => "Reply two",
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, _newer_thread, _meta} =
             Posts.create_post(
               board,
               %{"body" => "Newer body", "subject" => "Newer", "post" => "New Topic"},
               config: config,
               request: request
             )

    assert {:ok, first_page} = Posts.list_threads_page(board, 1, config: config)
    assert first_page.page == 1
    assert first_page.total_pages == 2
    assert Enum.map(first_page.pages, & &1.num) == [1, 2]
    assert hd(first_page.threads).thread.subject == "Newer"

    assert {:ok, second_page} = Posts.list_threads_page(board, 2, config: config)
    summary = hd(second_page.threads)
    assert summary.thread.id == older_thread.id
    assert summary.reply_count == 2
    assert summary.omitted_posts == 1
    assert Enum.map(summary.replies, & &1.body) == ["Reply two"]
  end

  test "thread views count image replies and omitted images" do
    board = board_fixture(%{config_overrides: %{threads_preview: 1}})
    config = post_config(board.config_overrides)
    request = post_request(board.uri)

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Opening body",
                 "file" => upload_fixture("op.png", "op"),
                 "post" => "New Topic"
               },
               config: config,
               request: request
             )

    assert {:ok, _reply_one, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "Reply one",
                 "file" => upload_fixture("reply1.png", "reply-one"),
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, _reply_two, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "Reply two",
                 "file" => upload_fixture("reply2.png", "reply-two"),
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert {:ok, page_data} = Posts.list_threads_page(board, 1, config: config)
    summary = hd(page_data.threads)

    assert summary.image_count == 3
    assert summary.omitted_posts == 1
    assert summary.omitted_images == 1

    assert {:ok, thread_view} = Posts.get_thread_view(board, thread.id, config: config)
    assert thread_view.image_count == 3
  end

  test "delete_post removes uploaded files for replies and threads" do
    board = board_fixture()
    config = post_config(board.config_overrides)
    request = post_request(board.uri)

    assert {:ok, thread, _meta} =
             Posts.create_post(
               board,
               %{
                 "body" => "Opening body",
                 "password" => "threadpw",
                 "file" => upload_fixture("thread.png", "thread"),
                 "post" => "New Topic"
               },
               config: config,
               request: request
             )

    assert {:ok, reply, _meta} =
             Posts.create_post(
               board,
               %{
                 "thread" => Integer.to_string(thread.id),
                 "body" => "Reply body",
                 "password" => "replypw",
                 "file" => upload_fixture("reply.png", "reply"),
                 "post" => "New Reply"
               },
               config: config,
               request: request
             )

    assert File.exists?(Eirinchan.Uploads.filesystem_path(reply.file_path))
    assert File.exists?(Eirinchan.Uploads.filesystem_path(reply.thumb_path))

    assert {:ok, %{thread_deleted: false}} =
             Posts.delete_post(board, reply.id, "replypw", config: config)

    refute File.exists?(Eirinchan.Uploads.filesystem_path(reply.file_path))
    refute File.exists?(Eirinchan.Uploads.filesystem_path(reply.thumb_path))
    assert File.exists?(Eirinchan.Uploads.filesystem_path(thread.file_path))
    assert File.exists?(Eirinchan.Uploads.filesystem_path(thread.thumb_path))

    assert {:ok, %{thread_deleted: true}} =
             Posts.delete_post(board, thread.id, "threadpw", config: config)

    refute File.exists?(Eirinchan.Uploads.filesystem_path(thread.file_path))
    refute File.exists?(Eirinchan.Uploads.filesystem_path(thread.thumb_path))
  end
end
