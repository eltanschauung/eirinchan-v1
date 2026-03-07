defmodule Eirinchan.UploadsFixtures do
  def upload_fixture(filename \\ "upload.png", content_or_opts \\ "fixture") do
    normalized_filename = filename |> to_string() |> String.trim()

    path =
      Path.join(
        System.tmp_dir!(),
        "eirinchan-upload-#{System.unique_integer([:positive])}-#{Path.basename(normalized_filename)}"
      )

    opts = normalize_opts(content_or_opts)

    case String.downcase(Path.extname(normalized_filename)) do
      ext when ext in [".png", ".jpg", ".jpeg", ".gif"] ->
        create_image!(path, opts)

      _ ->
        File.write!(path, opts.content)
    end

    %Plug.Upload{
      path: path,
      filename: filename,
      content_type: MIME.from_path(normalized_filename)
    }
  end

  def raw_upload_fixture(filename, content \\ "raw fixture") do
    path =
      Path.join(
        System.tmp_dir!(),
        "eirinchan-upload-raw-#{System.unique_integer([:positive])}-#{Path.basename(filename)}"
      )

    File.write!(path, content)

    %Plug.Upload{
      path: path,
      filename: filename,
      content_type: MIME.from_path(filename)
    }
  end

  def duplicate_upload_fixture(%Plug.Upload{} = upload, filename \\ nil) do
    duplicate_name = filename || upload.filename

    path =
      Path.join(
        System.tmp_dir!(),
        "eirinchan-upload-dup-#{System.unique_integer([:positive])}-#{Path.basename(duplicate_name)}"
      )

    File.cp!(upload.path, path)

    %Plug.Upload{
      path: path,
      filename: duplicate_name,
      content_type: upload.content_type
    }
  end

  defp normalize_opts(opts) when is_list(opts) do
    %{
      content: to_string(Keyword.get(opts, :content, "fixture")),
      geometry: Keyword.get(opts, :geometry, "16x16"),
      artist: Keyword.get(opts, :artist),
      orientation: Keyword.get(opts, :orientation)
    }
  end

  defp normalize_opts(content) do
    %{content: to_string(content), geometry: "16x16", artist: nil, orientation: nil}
  end

  defp create_image!(path, opts) do
    color =
      :crypto.hash(:md5, opts.content)
      |> Base.encode16(case: :lower)
      |> binary_part(0, 6)
      |> then(&"##{&1}")

    convert_args =
      ["-size", opts.geometry, "xc:#{color}"] ++
        if(is_binary(opts.artist), do: ["-set", "comment", opts.artist], else: []) ++ [path]

    {_, 0} = System.cmd("convert", convert_args)

    if is_binary(opts.artist) do
      {_, 0} = System.cmd("exiftool", ["-overwrite_original", "-Artist=#{opts.artist}", path])
    end

    if is_binary(opts.orientation) do
      {_, 0} =
        System.cmd("exiftool", ["-overwrite_original", "-Orientation=#{opts.orientation}", path])
    end

    path
  end
end
