defmodule Berth.MainRouter do
  @moduledoc """
  Main Plug router for upper level endpoints
  """

  use Plug.Router

  plug Plug.Logger
  plug :match
  plug :dispatch

  get "/" do
    send_resp(conn, 200, "Take a deep breath and berth")
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

end
