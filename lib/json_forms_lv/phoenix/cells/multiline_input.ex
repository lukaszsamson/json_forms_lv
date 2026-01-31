defmodule JsonFormsLV.Phoenix.Cells.MultilineInput do
  @moduledoc """
  Cell renderer for multiline string inputs.
  """

  use Phoenix.Component

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(%{"options" => %{"multi" => true}}, %{"type" => "string"}, _ctx), do: 12
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
        blur_event: blur_event
      )

    ~H"""
    <textarea
      id={@id}
      name={@path}
      disabled={@disabled?}
      phx-change={@change_event}
      phx-blur={@blur_event}
      phx-target={@target}
    ><%= @value %></textarea>
    """
  end

  defp disabled?(assigns) do
    not assigns.enabled? or assigns.readonly?
  end
end
