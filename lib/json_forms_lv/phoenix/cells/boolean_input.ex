defmodule JsonFormsLV.Phoenix.Cells.BooleanInput do
  @moduledoc """
  Cell renderer for boolean inputs.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(_uischema, %{"type" => "boolean"}, _ctx), do: 10
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    assigns =
      assigns
      |> Map.put(:checked?, assigns.value == true)
      |> Map.put(:disabled?, disabled?(assigns))

    ~H"""
    <input
      id={@id}
      name={@path}
      type="checkbox"
      checked={@checked?}
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
