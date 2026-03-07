defmodule EirinchanWeb.ManageSecurity do
  def generate_token do
    :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)
  end
end
