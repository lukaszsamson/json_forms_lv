defmodule JsonFormsLV.Phoenix.CellsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonFormsLV.Phoenix.Cells.{
    DateInput,
    DateTimeInput,
    EnumRadio,
    EnumSelect,
    MultilineInput
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
end
