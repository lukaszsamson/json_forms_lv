defmodule JsonFormsLV.Phoenix.Cells.EnumRadio do
  @moduledoc """
  Cell renderer for enum and oneOf radio groups.
  """

  use Phoenix.Component

  alias JsonFormsLV.Phoenix.Cells.EnumOptions
  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(%{"options" => %{"format" => "radio"}}, %{"enum" => enum}, _ctx)
      when is_list(enum) do
    22
  end

  def tester(%{"options" => %{"format" => "radio"}}, %{"oneOf" => one_of}, _ctx)
      when is_list(one_of) do
    21
  end

  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    change_event = if assigns.binding == :per_input, do: assigns.on_change
    blur_event = assigns.on_blur

    assigns =
      assigns
      |> assign(:disabled?, disabled?(assigns))
      |> assign(:options, EnumOptions.options(assigns))
      |> assign(:selected, assigns.value)
      |> assign(:change_event, change_event)
      |> assign(:blur_event, blur_event)

    ~H"""
    <div id={@id} data-jf-radio class="jf-radio-group">
      <%= for {option, index} <- Enum.with_index(@options) do %>
        <label for={"#{@id}-#{index}"} class="jf-radio-option">
          <input
            id={"#{@id}-#{index}"}
            name={@path}
            type="radio"
            value={option.value}
            checked={option.raw == @selected}
            disabled={@disabled?}
            phx-change={@change_event}
            phx-blur={@blur_event}
            phx-target={@target}
          />
          <span>{option.label}</span>
        </label>
      <% end %>
    </div>
    """
  end

  defp disabled?(assigns) do
    not assigns.enabled? or assigns.readonly?
  end
end
