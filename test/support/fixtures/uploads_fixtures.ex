defmodule Eirinchan.UploadsFixtures do
  def upload_fixture(filename \\ "upload.png", content \\ "fake image bytes") do
    path =
      Path.join(
        System.tmp_dir!(),
        "eirinchan-upload-#{System.unique_integer([:positive])}-#{filename}"
      )

    File.write!(path, content)

    %Plug.Upload{
      path: path,
      filename: filename,
      content_type: MIME.from_path(filename)
    }
  end
end
