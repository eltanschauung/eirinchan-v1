defmodule EirinchanWeb.UploadedFileController do
  use EirinchanWeb, :controller

  alias Eirinchan.Uploads

  def show(conn, %{"board" => board, "filename" => filename}) do
    if filename != Path.basename(filename) do
      send_resp(conn, :not_found, "File not found")
    else
      path = Uploads.filesystem_path("/#{board}/src/#{filename}")

      if File.exists?(path) do
        conn
        |> put_resp_content_type(MIME.from_path(path))
        |> send_file(200, path)
      else
        send_resp(conn, :not_found, "File not found")
      end
    end
  end
end
