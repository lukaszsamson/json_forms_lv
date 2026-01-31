defmodule JsonFormsLV.Phoenix.Cells.EnumSelect do
  @moduledoc """
  Cell renderer for enum and oneOf select inputs.
  """

  use Phoenix.Component

  alias JsonFormsLV.Phoenix.Cells.EnumOptions
  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(_uischema, %{"type" => "boolean"}, _ctx), do: :not_applicable

  def tester(_uischema, %{"enum" => enum} = schema, _ctx)
      when is_list(enum) and map_size(schema) > 0 do
    20
  end

  def tester(_uischema, %{"oneOf" => one_of} = schema, _ctx)
      when is_list(one_of) and map_size(schema) > 0 do
    19
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
      |> assign(:value, EnumOptions.encode_value(assigns.value))
      |> assign(:change_event, change_event)
      |> assign(:blur_event, blur_event)

    ~H"""
    <select
      id={@id}
      name={@path}
      disabled={@disabled?}
      phx-change={@change_event}
      phx-blur={@blur_event}
      phx-target={@target}
    >
      <%= for option <- @options do %>
        <option value={option.value} selected={option.value == @value}>{option.label}</option>
      <% end %>
    </select>
    """
  end

  defp disabled?(assigns) do
    not assigns.enabled? or assigns.readonly?
  end
end
