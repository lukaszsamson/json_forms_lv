defmodule JsonFormsLV.Phoenix.Cells.BooleanInput do
  @moduledoc """
  Cell renderer for boolean inputs.
  """

  use Phoenix.Component

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(_uischema, %{"type" => "boolean"}, _ctx), do: 10
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    change_event = if assigns.binding == :per_input, do: assigns.on_change
    blur_event = assigns.on_blur

    assigns =
      assign(assigns,
        checked?: assigns.value == true,
        disabled?: disabled?(assigns),
        change_event: change_event,
        blur_event: blur_event
      )

    ~H"""
    <input type="hidden" name={@path} value="false" disabled={@disabled?} />
    <input
      id={@id}
      name={@path}
      type="checkbox"
      value="true"
      checked={@checked?}
      disabled={@disabled?}
      phx-change={@change_event}
      phx-blur={@blur_event}
      phx-target={@target}
    />
    """
  end

  defp disabled?(assigns) do
    not assigns.enabled? or assigns.readonly?
  end
end
