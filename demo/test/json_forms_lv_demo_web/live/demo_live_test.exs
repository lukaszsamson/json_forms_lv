defmodule JsonFormsLvDemoWeb.DemoLiveTest do
  use JsonFormsLvDemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "updates data on change", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    assert has_element?(view, "#demo-json-forms-form")
    assert has_element?(view, "#debug-data", "\"name\": \"Ada\"")

    view
    |> element("#demo-json-forms-Control-name-input")
    |> render_change(%{"value" => "Grace", "path" => "name"})

    assert has_element?(view, "#debug-data", "\"name\": \"Grace\"")
  end

  test "shows validation errors after blur", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    view
    |> element("#demo-json-forms-Control-name-input")
    |> render_change(%{
      "value" => "",
      "path" => "name",
      "meta" => %{"touch" => true}
    })

    assert has_element?(view, "#debug-errors", "minLength")
  end

  test "shows validation errors after submit", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_change(view, "jf:change", %{"value" => "", "path" => "name"})

    refute has_element?(view, ".jf-errors")

    render_submit(view, "jf:submit", %{})

    assert has_element?(view, "#demo-submit-errors")
  end
end
