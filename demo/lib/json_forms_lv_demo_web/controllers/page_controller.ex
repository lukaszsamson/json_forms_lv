defmodule JsonFormsLvDemoWeb.PageController do
  use JsonFormsLvDemoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
