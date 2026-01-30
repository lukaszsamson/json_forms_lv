defmodule JsonFormsLvDemoWeb.DemoLiveTest do
  use JsonFormsLvDemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "updates data on change", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    assert has_element?(view, "#demo-json-forms-form")
    assert has_element?(view, "#debug-data", "\"name\": \"Ada\"")

    view
    |> element("input[name='name']")
    |> render_change(%{"value" => "Grace", "path" => "name"})

    assert has_element?(view, "#debug-data", "\"name\": \"Grace\"")
  end

  test "shows validation errors after blur", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    view
    |> element("input[name='name']")
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

  test "rules scenario hides and shows details", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_click(view, "select_scenario", %{"scenario" => "rules"})

    assert has_element?(view, "#demo-scenario", "rules")
    assert has_element?(view, "#debug-data", "\"show_details\"")
    assert has_element?(view, "#debug-uischema", "show_details")

    refute has_element?(view, "input[name='details']")

    render_change(view, "jf:change", %{"path" => "show_details", "value" => "true"})

    assert has_element?(view, "#debug-data", "\"show_details\": true")
    assert has_element?(view, "#debug-rules", "\"visible?\": true")
    assert has_element?(view, "input[name='details']")
  end
end
