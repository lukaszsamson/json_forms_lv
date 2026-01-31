defmodule JsonFormsLV.DispatchTest do
  use ExUnit.Case, async: true

  require Phoenix.LiveViewTest

  alias JsonFormsLV.{Dispatch, Registry}

  defmodule LowRenderer do
    @behaviour JsonFormsLV.Renderer

    def tester(%{"type" => "Control"}, _schema, _ctx), do: 5
    def tester(_uischema, _schema, _ctx), do: :not_applicable

    def render(_assigns), do: nil
  end

  defmodule HighRenderer do
    @behaviour JsonFormsLV.Renderer

    def tester(%{"type" => "Control"}, _schema, _ctx), do: 20
    def tester(_uischema, _schema, _ctx), do: :not_applicable

    def render(_assigns), do: nil
  end

  defmodule TieRendererA do
    @behaviour JsonFormsLV.Renderer

    def tester(%{"type" => "Control"}, _schema, _ctx), do: 10
    def tester(_uischema, _schema, _ctx), do: :not_applicable

    def render(_assigns), do: nil
  end

  defmodule TieRendererB do
    @behaviour JsonFormsLV.Renderer

    def tester(%{"type" => "Control"}, _schema, _ctx), do: 10
    def tester(_uischema, _schema, _ctx), do: :not_applicable

    def render(_assigns), do: nil
  end

  test "dispatch picks highest-ranked renderer" do
    registry =
      Registry.new(
        control_renderers: [LowRenderer, HighRenderer],
        layout_renderers: [],
        cell_renderers: []
      )

    ctx = %{}
    uischema = %{"type" => "Control"}
    schema = %{"type" => "string"}

    {module, _opts} = Dispatch.pick_renderer(uischema, schema, registry, ctx, :control)

    assert module == HighRenderer
  end

  test "dispatch picks first registered on rank tie" do
    registry =
      Registry.new(
        control_renderers: [TieRendererA, TieRendererB],
        layout_renderers: [],
        cell_renderers: []
      )

    ctx = %{}
    uischema = %{"type" => "Control"}
    schema = %{"type" => "string"}

    {module, _opts} = Dispatch.pick_renderer(uischema, schema, registry, ctx, :control)

    assert module == TieRendererA
  end

  test "dispatch returns nil for unknown kind" do
    registry = Registry.new()

    ctx = %{}
    uischema = %{"type" => "Mystery"}
    schema = %{"type" => "string"}

    assert Dispatch.pick_renderer(uischema, schema, registry, ctx, :unknown) == nil
  end

  test "dispatch preserves renderer options" do
    registry =
      Registry.new(
        control_renderers: [{JsonFormsLV.DispatchOptionRendererTest, foo: :bar}],
        layout_renderers: [],
        cell_renderers: []
      )

    ctx = %{}
    uischema = %{"type" => "Control"}
    schema = %{"type" => "string"}

    {module, opts} = Dispatch.pick_renderer(uischema, schema, registry, ctx, :control)

    assert module == JsonFormsLV.DispatchOptionRendererTest
    assert opts == [foo: :bar]
  end

  test "dispatch skips invalid or raising testers" do
    registry =
      Registry.new(
        control_renderers: [
          JsonFormsLV.DispatchRaisingRendererTest,
          JsonFormsLV.DispatchInvalidRendererTest,
          JsonFormsLV.DispatchFallbackRendererTest
        ],
        layout_renderers: [],
        cell_renderers: []
      )

    ctx = %{}
    uischema = %{"type" => "Control"}
    schema = %{"type" => "string"}

    {module, _opts} = Dispatch.pick_renderer(uischema, schema, registry, ctx, :control)

    assert module == JsonFormsLV.DispatchFallbackRendererTest
  end

  test "unknown renderer produces fallback output" do
    uischema = %{"type" => "Mystery"}

    assigns =
      %{
        id: "unknown",
        uischema: uischema,
        schema: %{},
        root_schema: %{},
        data: %{},
        path: "",
        instance_path: "",
        visible?: true,
        enabled?: true,
        readonly?: false,
        options: %{},
        i18n: %{},
        config: %{},
        form_id: "demo",
        on_change: "jf:change",
        on_blur: "jf:blur",
        on_submit: "jf:submit",
        target: nil,
        message: "Unknown element"
      }

    rendered =
      Phoenix.LiveViewTest.render_component(
        &JsonFormsLV.Phoenix.Renderers.Unknown.render/1,
        assigns
      )

    assert rendered =~ "Unknown element"
  end
end
