defmodule JsonFormsLvDemoWeb.ErrorJSONTest do
  use JsonFormsLvDemoWeb.ConnCase, async: true

  test "renders 404" do
    assert JsonFormsLvDemoWeb.ErrorJSON.render("404.json", %{}) == %{
             errors: %{detail: "Not Found"}
           }
  end

  test "renders 500" do
    assert JsonFormsLvDemoWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
