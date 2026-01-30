defmodule JsonFormsLvDemoWeb.DemoLiveTest do
  use JsonFormsLvDemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "updates data on change", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    assert has_element?(view, "#demo-json-forms")
    assert has_element?(view, "#debug-data", "\"name\": \"Ada\"")

    view
    |> element("#demo-json-forms-Control-name-input")
    |> render_change(%{"value" => "Grace", "path" => "name"})

    assert has_element?(view, "#debug-data", "\"name\": \"Grace\"")
  end
end
