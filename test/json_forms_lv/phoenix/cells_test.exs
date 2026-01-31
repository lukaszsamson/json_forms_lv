defmodule JsonFormsLV.Phoenix.CellsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonFormsLV.Phoenix.Cells.{
    DateInput,
    DateTimeInput,
    EnumRadio,
    EnumSelect,
    MultilineInput,
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
        data: %{"field" => "2025-01-01"}
      })

    html = render_component(&DateInput.render/1, assigns)

    assert html =~ ~s/type="date"/
    assert html =~ ~s/value="2025-01-01"/
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
