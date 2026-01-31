defmodule JsonFormsLV.Phoenix.CellsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonFormsLV.Phoenix.Cells.{
    BooleanInput,
    DateInput,
    DateTimeInput,
    EnumRadio,
    EnumSelect,
    MultilineInput,
    NumberInput,
    StringInput,
    TimeInput
  }

  defp base_assigns(overrides) do
    Map.merge(
      %{
        id: "field-id",
        path: "field",
        data: %{"field" => "value"},
        value: nil,
        binding: :per_input,
        on_change: "jf:change",
        on_blur: "jf:blur",
        target: nil,
        enabled?: true,
        readonly?: false,
        schema: %{},
        root_schema: %{},
        i18n: %{},
        ctx: %{},
        options: %{},
        aria_describedby: nil,
        aria_invalid: nil,
        aria_required: nil,
        required?: false,
        label: "Field"
      },
      overrides
    )
  end

  test "date input renders date type" do
    assigns =
      base_assigns(%{
        schema: %{"type" => "string", "format" => "date"},
        data: %{"field" => "2025-01-01"},
        i18n: %{locale: "es"}
      })

    html = render_component(&DateInput.render/1, assigns)

    assert html =~ ~s/type="date"/
    assert html =~ ~s/value="2025-01-01"/
    assert html =~ ~s/lang="es"/
  end

  test "date input exposes picker options" do
    assigns =
      base_assigns(%{
        schema: %{"type" => "string", "format" => "date"},
        data: %{"field" => "2025-01-01"},
        options: %{
          "dateFormat" => "YYYY-MM-DD",
          "dateSaveFormat" => "YYYY-MM-DD",
          "views" => ["year", "month", "day"],
          "clearLabel" => "Clear",
          "cancelLabel" => "Cancel",
          "okLabel" => "OK"
        }
      })

    html = render_component(&DateInput.render/1, assigns)

    assert html =~ ~s/data-jf-date-format="YYYY-MM-DD"/
    assert html =~ ~s/data-jf-date-save-format="YYYY-MM-DD"/
    assert html =~ ~s/data-jf-views="year,month,day"/
    assert html =~ ~s/data-jf-clear-label="Clear"/
    assert html =~ ~s/data-jf-cancel-label="Cancel"/
    assert html =~ ~s/data-jf-ok-label="OK"/
  end

  test "date-time input renders datetime-local type" do
    assigns =
      base_assigns(%{
        schema: %{"type" => "string", "format" => "date-time"},
        data: %{"field" => "2025-01-01T10:00"}
      })

    html = render_component(&DateTimeInput.render/1, assigns)

    assert html =~ ~s/type="datetime-local"/
    assert html =~ ~s/value="2025-01-01T10:00"/
  end

  test "date-time input exposes picker options" do
    assigns =
      base_assigns(%{
        schema: %{"type" => "string", "format" => "date-time"},
        data: %{"field" => "2025-01-01T10:00"},
        options: %{
          "dateTimeFormat" => "YYYY-MM-DD HH:mm",
          "dateTimeSaveFormat" => "YYYY-MM-DD HH:mm",
          "ampm" => true,
          "views" => ["year", "month", "day", "hours"],
          "okLabel" => "Apply"
        }
      })

    html = render_component(&DateTimeInput.render/1, assigns)

    assert html =~ ~s/data-jf-date-time-format="YYYY-MM-DD HH:mm"/
    assert html =~ ~s/data-jf-date-time-save-format="YYYY-MM-DD HH:mm"/
    assert html =~ ~s/data-jf-ampm="true"/
    assert html =~ ~s/data-jf-views="year,month,day,hours"/
    assert html =~ ~s/data-jf-ok-label="Apply"/
  end

  test "time input renders time type" do
    assigns =
      base_assigns(%{
        schema: %{"type" => "string", "format" => "time"},
        data: %{"field" => "09:30"}
      })

    html = render_component(&TimeInput.render/1, assigns)

    assert html =~ ~s/type="time"/
    assert html =~ ~s/value="09:30"/
  end

  test "time input exposes picker options" do
    assigns =
      base_assigns(%{
        schema: %{"type" => "string", "format" => "time"},
        data: %{"field" => "09:30"},
        options: %{
          "timeFormat" => "HH:mm",
          "timeSaveFormat" => "HH:mm",
          "ampm" => false,
          "clearLabel" => "Clear"
        }
      })

    html = render_component(&TimeInput.render/1, assigns)

    assert html =~ ~s/data-jf-time-format="HH:mm"/
    assert html =~ ~s/data-jf-time-save-format="HH:mm"/
    assert html =~ ~s/data-jf-ampm="false"/
    assert html =~ ~s/data-jf-clear-label="Clear"/
  end

  test "enum select renders options" do
    schema = %{"type" => "string", "enum" => ["alpha", "beta"]}

    assigns =
      base_assigns(%{
        schema: schema,
        root_schema: %{"type" => "object", "properties" => %{"field" => schema}},
        value: "beta"
      })

    html = render_component(&EnumSelect.render/1, assigns)

    assert html =~ ~s/<option value="alpha">/
    assert html =~ ~s/<option value="beta" selected>/
  end

  test "enum radio renders radio inputs" do
    schema = %{"type" => "string", "enum" => ["alpha", "beta"]}

    assigns =
      base_assigns(%{
        schema: schema,
        root_schema: %{"type" => "object", "properties" => %{"field" => schema}},
        value: "alpha",
        label: "Choice"
      })

    html = render_component(&EnumRadio.render/1, assigns)

    assert html =~ ~s/type="radio"/
    assert html =~ "Choice"
  end

  test "multiline input renders textarea" do
    assigns = base_assigns(%{value: "Line 1", options: %{"multi" => true}})

    html = render_component(&MultilineInput.render/1, assigns)

    assert html =~ "<textarea"
    assert html =~ "Line 1"
  end

  test "multiline input respects restrict option" do
    assigns =
      base_assigns(%{
        schema: %{"type" => "string", "maxLength" => 10},
        options: %{"multi" => true, "restrict" => true}
      })

    html = render_component(&MultilineInput.render/1, assigns)

    assert html =~ ~s/maxlength="10"/
  end

  test "string input uses placeholder" do
    assigns = base_assigns(%{options: %{"placeholder" => "Enter name"}})

    html = render_component(&StringInput.render/1, assigns)

    assert html =~ ~s/placeholder="Enter name"/
  end

  test "string input renders suggestion datalist" do
    assigns =
      base_assigns(%{
        options: %{"suggestion" => ["Alpha", "Beta"]}
      })

    html = render_component(&StringInput.render/1, assigns)

    assert html =~ "<datalist"
    assert html =~ ~s/option value="Alpha"/
    assert html =~ ~s/option value="Beta"/
  end

  test "string input respects restrict and trim options" do
    assigns =
      base_assigns(%{
        schema: %{"type" => "string", "maxLength" => 5},
        options: %{"restrict" => true, "trim" => true}
      })

    html = render_component(&StringInput.render/1, assigns)

    assert html =~ ~s/maxlength="5"/
    assert html =~ ~s/size="5"/
  end

  test "boolean input renders toggle switch" do
    assigns = base_assigns(%{value: true, options: %{"toggle" => true}})

    html = render_component(&BooleanInput.render/1, assigns)

    assert html =~ ~s/role="switch"/
    assert html =~ ~s/data-jf-toggle="true"/
    assert html =~ ~s/aria-checked="true"/
  end

  test "number input renders slider" do
    assigns =
      base_assigns(%{
        schema: %{"type" => "number", "minimum" => 0, "maximum" => 10, "multipleOf" => 0.5},
        value: 2.5,
        options: %{"slider" => true}
      })

    html = render_component(&NumberInput.render/1, assigns)

    assert html =~ ~s/type="range"/
    assert html =~ ~s/min="0"/
    assert html =~ ~s/max="10"/
    assert html =~ ~s/step="0.5"/
  end

  test "enum select renders autocomplete datalist" do
    schema = %{"type" => "string", "enum" => ["alpha", "beta"]}

    assigns =
      base_assigns(%{
        schema: schema,
        root_schema: %{"type" => "object", "properties" => %{"field" => schema}},
        options: %{"autocomplete" => true}
      })

    html = render_component(&EnumSelect.render/1, assigns)

    assert html =~ "<datalist"
    assert html =~ ~s/type="text"/
    assert html =~ ~s/option value="alpha"/
    assert html =~ ~s/option value="beta"/
  end

  test "enum select exposes dynamic enum status" do
    schema = %{
      "type" => "string",
      "enum" => ["alpha"],
      "x-url" => "https://example.com/enums/status"
    }

    assigns =
      base_assigns(%{
        schema: schema,
        root_schema: %{"type" => "object", "properties" => %{"field" => schema}},
        config: %{},
        ctx: %{
          dynamic_enums_status: %{"https://example.com/enums/status" => {:loading, :pending}}
        }
      })

    html = render_component(&EnumSelect.render/1, assigns)

    assert html =~ ~s/data-jf-enum-status="loading"/
  end

  test "time input uses placeholder" do
    assigns =
      base_assigns(%{
        schema: %{"type" => "string", "format" => "time"},
        data: %{"field" => "09:30"},
        options: %{"placeholder" => "Pick a time"}
      })

    html = render_component(&TimeInput.render/1, assigns)

    assert html =~ ~s/placeholder="Pick a time"/
  end
end
