defmodule EirinchanWeb.Router do
  use EirinchanWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EirinchanWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/manage", EirinchanWeb do
    pipe_through :api

    get "/boards", BoardManagementController, :index
    post "/boards", BoardManagementController, :create
    get "/boards/:uri", BoardManagementController, :show
    patch "/boards/:uri", BoardManagementController, :update
    delete "/boards/:uri", BoardManagementController, :delete
  end

  scope "/", EirinchanWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/:board", BoardController, :show
    post "/:board/post", PostController, :create
    get "/:board/res/:thread_id", ThreadController, :show
  end
end
