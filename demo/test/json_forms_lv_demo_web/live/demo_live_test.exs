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
    assert has_element?(view, "input[type='time'][name='start_time']")
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

  test "suggestions scenario renders datalist autocomplete", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_click(view, "select_scenario", %{"scenario" => "suggestions"})

    assert has_element?(view, "#demo-scenario", "suggestions")
    assert has_element?(view, "input[type='text'][name='assignee'][list]")
    assert has_element?(view, "input[type='text'][name='estimate'][list]")
    assert has_element?(view, "input[type='text'][name='status'][list]")
    assert has_element?(view, "datalist option[value='Ada']")
    assert has_element?(view, "datalist option[value='open']")
  end

  test "defaults scenario applies schema defaults", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_click(view, "select_scenario", %{"scenario" => "defaults"})

    assert has_element?(view, "#demo-scenario", "defaults")
    assert has_element?(view, "#debug-data", "\"name\": \"Ada\"")
    assert has_element?(view, "#debug-data", "\"priority\": 2")
    assert has_element?(view, "#debug-data", "\"status\": \"open\"")
    assert has_element?(view, "input[name='name'][value='Ada']")
    assert has_element?(view, "input[name='priority'][value='2']")
    assert has_element?(view, "select[name='status'] option[value='open'][selected]")
  end

  test "remote uischema scenario loads via loader", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_click(view, "select_scenario", %{"scenario" => "remote-uischema"})

    assert has_element?(view, "#demo-scenario", "remote-uischema")
    assert has_element?(view, ".jf-group-label", "Remote UI")
    assert has_element?(view, "input[name='name']")
  end

  test "conditionals scenario toggles conditional fields", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_click(view, "select_scenario", %{"scenario" => "conditionals"})

    assert has_element?(view, "#demo-scenario", "conditionals")
    assert has_element?(view, "select[name='mode']")
    assert has_element?(view, "input[name='summary']")
    refute has_element?(view, "input[name='details']")

    render_change(view, "jf:change", %{"path" => "mode", "value" => "advanced"})

    assert has_element?(view, "input[name='details']")
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
    assert has_element?(view, "[data-jf-label]", "Schedule")

    render_click(view, "set_locale", %{"locale" => "es"})

    assert has_element?(view, "#demo-locale", "es")
    assert has_element?(view, "[data-jf-label]", "Horario")
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

  test "arrays scenario supports add and remove", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_click(view, "select_scenario", %{"scenario" => "arrays"})

    assert stream_container?(view)

    assert has_element?(view, "#demo-scenario", "arrays")
    assert has_element?(view, "#debug-data", "\"title\": \"Plan\"")

    render_click(view, "jf:add_item", %{"path" => "tasks"})

    assert has_element?(view, "#debug-data", "\"title\": \"\"")

    render_click(view, "jf:remove_item", %{"path" => "tasks", "index" => "0"})

    refute has_element?(view, "#debug-data", "\"title\": \"Plan\"")
  end

  test "arrays registered detail uses detail registry", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_click(view, "select_scenario", %{"scenario" => "arrays-registered"})

    assert has_element?(view, "#demo-scenario", "arrays-registered")
    assert has_element?(view, "input[name='tasks.0.title']")
    refute has_element?(view, "input[name='tasks.0.done']")
  end

  test "custom renderer scenario uses custom cell", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_click(view, "select_scenario", %{"scenario" => "custom"})

    assert has_element?(view, "#demo-scenario", "custom")
    assert has_element?(view, "input[name='message'][data-custom-cell='shout']")
    refute has_element?(view, "input[name='note'][data-custom-cell='shout']")
    assert has_element?(view, "section[data-custom-control='callout']")
  end

  test "streaming arrays keep stable dom ids", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_click(view, "select_scenario", %{"scenario" => "arrays"})

    build_id = array_item_id_for_title(view, "Build")
    assert is_binary(build_id)

    render_click(view, "jf:move_item", %{"path" => "tasks", "from" => "1", "to" => "0"})

    assert array_item_id_for_title(view, "Build") == build_id

    render_click(view, "jf:add_item", %{"path" => "tasks"})

    assert array_item_id_for_title(view, "Build") == build_id

    render_click(view, "jf:remove_item", %{"path" => "tasks", "index" => "1"})

    assert array_item_id_for_title(view, "Build") == build_id
  end

  test "validation scenario toggles modes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/demo")

    render_click(view, "select_scenario", %{"scenario" => "validation"})

    assert has_element?(view, "#demo-scenario", "validation")
    assert has_element?(view, "#demo-validation-mode", "validate_and_hide")

    render_click(view, "set_validation_mode", %{"mode" => "no_validation"})

    assert has_element?(view, "#demo-validation-mode", "no_validation")
  end

  defp array_item_id_for_title(view, title) do
    html = render(view)
    document = LazyHTML.from_fragment(html)
    items = LazyHTML.query(document, "div[data-jf-array-item]")

    Enum.find_value(items, fn item ->
      inputs = LazyHTML.query(item, "input[type='text'][value='#{title}']")

      if Enum.count(inputs) > 0 do
        case LazyHTML.attribute(item, "id") do
          [id] -> id
          _ -> nil
        end
      end
    end)
  end

  defp stream_container?(view) do
    html = render(view)
    document = LazyHTML.from_fragment(html)

    containers =
      LazyHTML.query(document, "div[data-jf-control][data-jf-array] div[phx-update='stream']")

    Enum.count(containers) == 1
  end
end
