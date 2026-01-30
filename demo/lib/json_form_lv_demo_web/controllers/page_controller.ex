defmodule JsonFormLvDemoWeb.PageController do
  use JsonFormLvDemoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
