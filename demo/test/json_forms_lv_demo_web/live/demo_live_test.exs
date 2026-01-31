defmodule JsonFormsLvDemoWeb.DemoLiveTest do
  use JsonFormsLvDemoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "updates data on change", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    assert has_element?(view, "#demo-json-forms-form")
    assert has_element?(view, "#debug-data", "\"name\": \"Ada\"")

    view
    |> render_change("jf:change", %{
      "_target" => ["jf", "name"],
      "jf" => %{"name" => "Grace"}
    })

    assert has_element?(view, "#debug-data", "\"name\": \"Grace\"")
  end

  test "shows validation errors after blur", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_change(view, "jf:change", %{
      "_target" => ["jf", "name"],
      "jf" => %{"name" => ""}
    })

    render_blur(view, "jf:blur", %{"_target" => ["jf", "name"]})

    assert has_element?(view, "#debug-errors", "minLength")
  end

  test "shows validation errors after submit", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_change(view, "jf:change", %{
      "_target" => ["jf", "name"],
      "jf" => %{"name" => ""}
    })

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

    render_change(view, "jf:change", %{
      "_target" => ["jf", "show_details"],
      "jf" => %{"show_details" => "true"}
    })

    assert has_element?(view, "#debug-data", "\"show_details\": true")
    assert has_element?(view, "#debug-rules", "\"visible?\": true")
    assert has_element?(view, "input[name='details']")
  end

  test "formats scenario handles enums and date inputs", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_click(view, "select_scenario", %{"scenario" => "formats"})

    assert has_element?(view, "#demo-scenario", "formats")
    assert has_element?(view, "input[type='radio'][name='status']")
    assert has_element?(view, "select[name='priority']")
    assert has_element?(view, "input[type='date'][name='start_date']")
    assert has_element?(view, "input[type='datetime-local'][name='meeting']")
    assert has_element?(view, "textarea[name='notes']")

    view
    |> render_change("jf:change", %{
      "_target" => ["jf", "priority"],
      "jf" => %{"priority" => "2"}
    })

    assert has_element?(view, "#debug-data", "\"priority\": 2")

    render_submit(view, "jf:submit", %{})

    assert has_element?(view, "select[name='priority'] option[value='2'][selected]")

    view
    |> render_change("jf:change", %{
      "_target" => ["jf", "start_date"],
      "jf" => %{"start_date" => ""}
    })

    render_blur(view, "jf:blur", %{"_target" => ["jf", "start_date"]})

    assert has_element?(view, "#debug-errors", "minLength")
  end

  test "formats scenario preserves date values across changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_click(view, "select_scenario", %{"scenario" => "formats"})

    view
    |> render_change("jf:change", %{
      "_target" => ["jf", "start_date"],
      "jf" => %{"start_date" => "2025-01-29"}
    })

    assert has_element?(view, "#debug-data", "2025-01-29")
    assert has_element?(view, "input[name='start_date'][value='2025-01-29']")

    view
    |> render_change("jf:change", %{
      "_target" => ["jf", "meeting"],
      "jf" => %{"meeting" => "2025-01-21T10:00"}
    })

    assert has_element?(view, "input[name='start_date'][value='2025-01-29']")
    assert has_element?(view, "input[name='meeting'][value='2025-01-21T10:00']")

    render_submit(view, "jf:submit", %{})

    assert has_element?(view, "input[name='start_date'][value='2025-01-29']")
    assert has_element?(view, "input[name='meeting'][value='2025-01-21T10:00']")
  end

  test "i18n scenario toggles locale", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_click(view, "select_scenario", %{"scenario" => "i18n"})

    assert has_element?(view, "#demo-scenario", "i18n")
    assert has_element?(view, "#demo-locale", "en")
    assert has_element?(view, "#demo-json-forms-i18n-welcome-root", "Schedule")

    render_click(view, "set_locale", %{"locale" => "es"})

    assert has_element?(view, "#demo-locale", "es")
    assert has_element?(view, "#demo-json-forms-i18n-welcome-root", "Horario")
  end

  test "readonly scenario disables inputs", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_click(view, "select_scenario", %{"scenario" => "readonly"})

    assert has_element?(view, "#demo-scenario", "readonly")
    assert has_element?(view, "input[name='name'][disabled]")
  end

  test "readonly precedence scenario keeps schema and uischema locked", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_click(view, "select_scenario", %{"scenario" => "readonly-precedence"})

    assert has_element?(view, "#demo-scenario", "readonly-precedence")
    refute has_element?(view, "input[name='name'][disabled]")
    assert has_element?(view, "input[name='code'][disabled]")
    assert has_element?(view, "input[name='note'][disabled]")

    render_click(view, "toggle_readonly", %{})

    assert has_element?(view, "input[name='name'][disabled]")
  end
end
