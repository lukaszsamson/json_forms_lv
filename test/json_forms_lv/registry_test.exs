defmodule JsonFormsLV.RegistryTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.Registry

  defmodule RendererA do
  end

  defmodule RendererB do
  end

  test "merge places custom before defaults" do
    custom = Registry.new(control_renderers: [RendererA])
    defaults = Registry.new(control_renderers: [RendererB])

    merged = Registry.merge(custom, defaults)

    assert merged.control_renderers == [RendererA, RendererB]
  end

  test "register_control prepends entry" do
    registry = Registry.new(control_renderers: [RendererB])
    registry = Registry.register_control(registry, RendererA)

    assert registry.control_renderers == [RendererA, RendererB]
  end

  test "register_cells prepends entries" do
    registry = Registry.new(cell_renderers: [RendererB])
    registry = Registry.register_cells(registry, [RendererA])

    assert registry.cell_renderers == [RendererA, RendererB]
  end
end
