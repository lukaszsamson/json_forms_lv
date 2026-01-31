defmodule JsonFormsLV.Phoenix.ControlRendererTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonFormsLV.Phoenix.Renderers.Control
  alias JsonFormsLV.Registry

  defp base_assigns(overrides) do
    Map.merge(
      %{
        id: "control-1",
        uischema: %{"type" => "Control", "scope" => "#/properties/name"},
        schema: %{"type" => "string"},
        root_schema: %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}},
        data: %{"name" => "Ada"},
        path: "name",
        instance_path: "/name",
        value: "Ada",
        visible?: true,
        enabled?: true,
        readonly?: false,
        required?: true,
        options: %{},
        i18n: %{},
        config: %{},
        ctx: %{},
        errors_for_control: [],
        show_errors?: false,
        registry: Registry.new(cell_renderers: [JsonFormsLV.Phoenix.Cells.StringInput]),
        binding: :per_input,
        on_change: "jf:change",
        on_blur: "jf:blur",
        on_submit: "jf:submit",
        target: nil
      },
      overrides
    )
  end

  test "required label includes asterisk by default" do
    assigns = base_assigns(%{options: %{}})

    html = render_component(&Control.render/1, assigns)

    assert html =~ "Name *"
  end

  test "hideRequiredAsterisk removes asterisk" do
    assigns = base_assigns(%{options: %{"hideRequiredAsterisk" => true}})

    html = render_component(&Control.render/1, assigns)

    assert html =~ "Name"
    refute html =~ "Name *"
  end

  test "showUnfocusedDescription toggles focus class" do
    assigns =
      base_assigns(%{
        schema: %{"type" => "string", "description" => "Help"},
        options: %{"showUnfocusedDescription" => false}
      })

    html = render_component(&Control.render/1, assigns)

    assert html =~ "jf-description--focus"
    assert html =~ "Help"
  end
end
