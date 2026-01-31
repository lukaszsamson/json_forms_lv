defmodule JsonFormsLV.DispatchInvalidRendererTest do
  @behaviour JsonFormsLV.Renderer

  def tester(_uischema, _schema, _ctx), do: :oops

  def render(_assigns), do: nil
end
