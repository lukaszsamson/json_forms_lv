defmodule JsonFormsLV.DispatchFallbackRendererTest do
  @behaviour JsonFormsLV.Renderer

  def tester(%{"type" => "Control"}, _schema, _ctx), do: 1
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  def render(_assigns), do: nil
end
