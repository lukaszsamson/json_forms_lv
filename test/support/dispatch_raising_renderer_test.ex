defmodule JsonFormsLV.DispatchRaisingRendererTest do
  @behaviour JsonFormsLV.Renderer

  def tester(_uischema, _schema, _ctx), do: raise("boom")

  def render(_assigns), do: nil
end
