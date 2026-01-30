defmodule JsonFormsLV.Phoenix.Cells.StringInput do
  @moduledoc """
  Cell renderer for string inputs.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(_uischema, %{"type" => "string"}, _ctx), do: 10
  def tester(_uischema, nil, _ctx), do: 1
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    assigns = assign(assigns, disabled?: disabled?(assigns), value: assigns.value || "")

    ~H"""
    <input
      id={@id}
      name={@path}
      type="text"
      value={@value}
      disabled={@disabled?}
      phx-change={
        JS.push(@on_change, value: %{path: @path, meta: %{touch: true}}, target: @target)
      }
      phx-blur={JS.push(@on_blur, value: %{path: @path, meta: %{touch: true}}, target: @target)}
    />
    """
  end

  defp disabled?(assigns) do
    not assigns.enabled? or assigns.readonly?
  end
end
