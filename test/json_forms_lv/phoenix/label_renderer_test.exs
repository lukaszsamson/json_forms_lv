defmodule JsonFormsLV.Phoenix.LabelRendererTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonFormsLV.Phoenix.Renderers.Label

  test "label renderer outputs translated text" do
    translate = fn _key, default, _ctx -> "#{default} (i18n)" end

    assigns = %{
      id: "label-1",
      uischema: %{"type" => "Label", "text" => "Hello"},
      i18n: %{translate: translate},
      ctx: %{uischema: %{}, schema: %{}, path: ""},
      visible?: true
    }

    html = render_component(&Label.render/1, assigns)

    assert html =~ "Hello (i18n)"
  end

  test "label renderer respects label object show false" do
    assigns = %{
      id: "label-2",
      uischema: %{
        "type" => "Label",
        "text" => "Hidden",
        "label" => %{"show" => false}
      },
      i18n: %{},
      ctx: %{uischema: %{}, schema: %{}, path: ""},
      visible?: true
    }

    html = render_component(&Label.render/1, assigns)

    refute html =~ "Hidden"
  end
end
