defmodule JsonFormsLV.LayoutRendererTestSupport do
  @behaviour JsonFormsLV.Renderer

  def tester(%{"type" => "Group"}, _schema, _ctx), do: 12
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  def render(_assigns), do: nil
end
