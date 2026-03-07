defmodule Eirinchan.Runtime do
  @moduledoc """
  Bootstrap helpers for request-scoped runtime state.
  """

  alias Eirinchan.Runtime.{Config, RequestContext}

  @spec bootstrap(keyword()) :: RequestContext.t()
  def bootstrap(opts \\ []) do
    defaults = Keyword.get(opts, :defaults)
    instance_overrides = Keyword.get(opts, :instance_overrides, %{})
    request_host = Keyword.get(opts, :request_host)

    %RequestContext{
      config: Config.compose(defaults, instance_overrides, %{}, request_host: request_host)
    }
  end
end
