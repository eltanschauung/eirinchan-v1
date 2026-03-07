defmodule Eirinchan.Uploads do
  @moduledoc """
  Minimal single-file upload storage backed by the board build directory.
  """

  alias Eirinchan.Boards.BoardRecord
  alias Eirinchan.Posts.Post

  @image_extensions [".png", ".jpg", ".jpeg", ".gif"]

  @spec describe(Plug.Upload.t(), map()) :: {:ok, map()} | {:error, atom()}
  def describe(%Plug.Upload{} = upload, config) do
    normalized_name = normalized_input_filename(upload.filename)

    with {:ok, binary} <- File.read(upload.path) do
      ext =
        normalized_name
        |> Path.extname()
        |> String.downcase()

      file_type = detect_mime_type(upload.path, normalized_name)
      image_metadata = maybe_image_metadata(upload.path, file_type)

      {:ok,
       %{
         binary: binary,
         ext: ext,
         file_name: normalized_filename(normalized_name, config),
         file_size: byte_size(binary),
         file_type: file_type,
         file_md5: :crypto.hash(:md5, binary) |> Base.encode64(),
         image_width: image_metadata.width,
         image_height: image_metadata.height,
         spoiler: false
       }}
    else
      {:error, _reason} -> {:error, :upload_failed}
    end
  end

  @spec store(BoardRecord.t(), Post.t(), Plug.Upload.t(), map()) ::
          {:ok, map()} | {:error, atom()}
  def store(%BoardRecord{} = board, %Post{} = post, %Plug.Upload{} = upload, config) do
    with {:ok, metadata} <- describe(upload, config) do
      store(board, post, upload, config, metadata, nil)
    end
  end

  @spec store(BoardRecord.t(), Post.t(), Plug.Upload.t(), map(), map()) ::
          {:ok, map()} | {:error, atom()}
  def store(%BoardRecord{} = board, %Post{} = post, %Plug.Upload{} = upload, config, metadata) do
    store(board, post, upload, config, metadata, nil)
  end

  @spec store(BoardRecord.t(), Post.t(), Plug.Upload.t(), map(), map(), String.t() | nil) ::
          {:ok, map()} | {:error, atom()}
  def store(
        %BoardRecord{} = board,
        %Post{} = post,
        %Plug.Upload{} = upload,
        config,
        metadata,
        suffix
      ) do
    base_name = if is_binary(suffix), do: "#{post.id}-#{suffix}", else: "#{post.id}"
    storage_name = "#{base_name}#{metadata.ext}"
    destination = Path.join([board_root(), board.uri, config.dir.img, storage_name])
    thumb_name = "#{base_name}s.png"
    thumb_destination = Path.join([board_root(), board.uri, config.dir.thumb, thumb_name])

    destination
    |> Path.dirname()
    |> File.mkdir_p!()

    thumb_destination
    |> Path.dirname()
    |> File.mkdir_p!()

    case File.cp(upload.path, destination) do
      :ok ->
        case generate_thumbnail(destination, thumb_destination, config, metadata) do
          :ok ->
            {:ok,
             Map.merge(metadata, %{
               file_path: "/#{board.uri}/#{config.dir.img}#{storage_name}",
               thumb_path: "/#{board.uri}/#{config.dir.thumb}#{thumb_name}"
             })}

          {:error, reason} ->
            _ = File.rm(destination)
            _ = File.rm(thumb_destination)
            {:error, reason}
        end

      {:error, _reason} ->
        {:error, :upload_failed}
    end
  end

  @spec remove(String.t() | nil) :: :ok
  def remove(nil), do: :ok

  def remove(file_path) when is_binary(file_path) do
    _ = File.rm(filesystem_path(file_path))
    :ok
  end

  @spec filesystem_path(String.t()) :: String.t()
  def filesystem_path(file_path) do
    sanitized =
      file_path
      |> String.trim_leading("/")
      |> Path.split()
      |> Enum.reject(&(&1 in [".", ".."]))

    Path.join([board_root() | sanitized])
  end

  @spec board_root() :: String.t()
  def board_root do
    Application.fetch_env!(:eirinchan, :build_output_root)
  end

  def image?(%{file_type: file_type}) when is_binary(file_type),
    do: String.starts_with?(file_type, "image/")

  def image?(_metadata), do: false

  def compatible_with_extension?(%{ext: ext, file_type: file_type}),
    do: compatible_with_extension?(ext, file_type)

  def compatible_with_extension?(ext, file_type)
      when is_binary(ext) and is_binary(file_type) do
    cond do
      ext in [".jpg", ".jpeg"] -> file_type == "image/jpeg"
      ext == ".png" -> file_type == "image/png"
      ext == ".gif" -> file_type == "image/gif"
      ext == ".txt" -> file_type == "inode/x-empty" or String.starts_with?(file_type, "text/")
      true -> true
    end
  end

  def compatible_with_extension?(_ext, _file_type), do: false

  def image_extension?(ext) when is_binary(ext), do: ext in @image_extensions
  def image_extension?(_ext), do: false

  defp maybe_image_metadata(path, file_type) do
    if String.starts_with?(file_type, "image/") do
      case image_metadata(path) do
        {:ok, data} -> data
        {:error, :invalid_image} -> %{width: nil, height: nil}
      end
    else
      %{width: nil, height: nil}
    end
  end

  defp detect_mime_type(path, normalized_name) do
    case System.cmd("file", ["--mime-type", "-b", path], stderr_to_stdout: true) do
      {output, 0} ->
        case String.trim(output) do
          "" -> MIME.from_path(normalized_name)
          mime_type -> mime_type
        end

      _ ->
        MIME.from_path(normalized_name)
    end
  end

  defp image_metadata(path) do
    case System.cmd("identify", ["-format", "%w %h", path], stderr_to_stdout: true) do
      {output, 0} ->
        case String.split(String.trim(output), ~r/\s+/, parts: 2) do
          [width, height] ->
            {:ok, %{width: String.to_integer(width), height: String.to_integer(height)}}

          _ ->
            {:error, :invalid_image}
        end

      _ ->
        {:error, :invalid_image}
    end
  end

  defp generate_thumbnail(source, destination, config, metadata) do
    cond do
      Map.get(metadata, :spoiler) ->
        generate_spoiler_thumbnail(destination, config)

      image?(metadata) ->
        generate_image_thumbnail(source, destination, config)

      true ->
        generate_placeholder_thumbnail(destination, config, metadata)
    end
  end

  defp generate_image_thumbnail(source, destination, config) do
    geometry = "#{config.thumb_width}x#{config.thumb_height}"

    case System.cmd(
           "convert",
           [source, "-auto-orient", "-thumbnail", geometry, destination],
           stderr_to_stdout: true
         ) do
      {_output, 0} -> :ok
      _ -> {:error, :upload_failed}
    end
  end

  defp generate_placeholder_thumbnail(destination, config, metadata) do
    size = "#{config.thumb_width}x#{config.thumb_height}"

    label =
      metadata.file_name
      |> Path.extname()
      |> String.trim_leading(".")
      |> String.upcase()
      |> case do
        "" -> "FILE"
        ext -> ext
      end

    case System.cmd(
           "convert",
           [
             "-size",
             size,
             "xc:#f1ede3",
             "-fill",
             "#3b3426",
             "-gravity",
             "center",
             "-pointsize",
             "28",
             "-annotate",
             "0",
             label,
             destination
           ],
           stderr_to_stdout: true
         ) do
      {_output, 0} -> :ok
      _ -> {:error, :upload_failed}
    end
  end

  defp generate_spoiler_thumbnail(destination, config) do
    size = "#{config.thumb_width}x#{config.thumb_height}"

    case System.cmd(
           "convert",
           [
             "-size",
             size,
             "xc:#202020",
             "-fill",
             "#f0f0f0",
             "-gravity",
             "center",
             "-pointsize",
             "26",
             "-annotate",
             "0",
             "SPOILER",
             destination
           ],
           stderr_to_stdout: true
         ) do
      {_output, 0} -> :ok
      _ -> {:error, :upload_failed}
    end
  end

  defp normalized_filename(filename, config) do
    original_ext = Path.extname(filename)

    ext =
      filename
      |> Path.extname()
      |> String.downcase()

    max_length = max(config.max_filename_display_length || 64, 1)

    base =
      filename
      |> Path.basename(original_ext)
      |> String.trim()
      |> String.replace(~r/[[:cntrl:]]+/u, "")
      |> String.replace(~r/[^A-Za-z0-9._-]+/u, "_")
      |> String.trim("_")
      |> case do
        "" -> "file"
        sanitized -> sanitized
      end
      |> String.slice(0, max_length)

    base <> ext
  end

  defp normalized_input_filename(filename) do
    filename
    |> to_string()
    |> String.trim()
    |> case do
      "" -> "file"
      trimmed -> trimmed
    end
  end
end
