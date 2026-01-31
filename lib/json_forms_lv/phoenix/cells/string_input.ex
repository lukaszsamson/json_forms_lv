defmodule JsonFormsLV.Phoenix.Cells.StringInput do
  @moduledoc """
  Cell renderer for string inputs.
  """

  use Phoenix.Component

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(_uischema, %{"type" => "string"}, _ctx), do: 10
  def tester(_uischema, nil, _ctx), do: 1
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    change_event = if assigns.binding == :per_input, do: assigns.on_change
    blur_event = assigns.on_blur

    assigns =
      assign(assigns,
        disabled?: disabled?(assigns),
        value: assigns.value || "",
        change_event: change_event,
        blur_event: blur_event,
        aria_describedby: assigns[:aria_describedby],
        aria_invalid: assigns[:aria_invalid],
        aria_required: assigns[:aria_required]
      )

    ~H"""
    <input
      id={@id}
      name={@path}
      type="text"
      value={@value}
      disabled={@disabled?}
      aria-describedby={@aria_describedby}
      aria-invalid={@aria_invalid}
      aria-required={@aria_required}
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
