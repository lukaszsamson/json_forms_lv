defmodule JsonFormsLV.Phoenix.Cells.EnumRadio do
  @moduledoc """
  Cell renderer for enum and oneOf radio groups.
  """

  use Phoenix.Component

  alias JsonFormsLV.DynamicEnums
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
    locale = locale(assigns)
    enum_status = enum_status(assigns)
    enum_status_value = status_value(enum_status)

    assigns =
      assigns
      |> assign(:disabled?, disabled?(assigns))
      |> assign(:options, EnumOptions.options(assigns))
      |> assign(:selected, assigns.value)
      |> assign(:change_event, change_event)
      |> assign(:blur_event, blur_event)
      |> assign(:locale, locale)
      |> assign(:enum_status, enum_status_value)
      |> assign(:aria_describedby, assigns[:aria_describedby])
      |> assign(:aria_invalid, assigns[:aria_invalid])
      |> assign(:aria_required, assigns[:aria_required])
      |> assign(:label, assigns[:label])

    ~H"""
    <fieldset
      id={@id}
      data-jf-radio
      data-jf-enum-status={@enum_status}
      class="jf-radio-group"
      role="radiogroup"
    >
      <%= if @label do %>
        <legend class="jf-radio-legend">{@label}</legend>
      <% end %>
      <%= for {option, index} <- Enum.with_index(@options) do %>
        <label for={"#{@id}-#{index}"} class="jf-radio-option">
          <input
            id={"#{@id}-#{index}"}
            name={@path}
            type="radio"
            value={option.value}
            checked={option.raw == @selected}
            disabled={@disabled?}
            lang={@locale}
            aria-describedby={@aria_describedby}
            aria-invalid={@aria_invalid}
            aria-required={@aria_required}
            phx-change={@change_event}
            phx-blur={@blur_event}
            phx-target={@target}
          />
          <span>{option.label}</span>
        </label>
      <% end %>
    </fieldset>
    """
  end

  defp disabled?(assigns) do
    not assigns.enabled? or assigns.readonly?
  end

  defp enum_status(assigns) do
    status_map = Map.get(assigns.ctx || %{}, :dynamic_enums_status) || %{}
    DynamicEnums.status_for(assigns.schema || %{}, Map.get(assigns, :config, %{}), status_map)
  end

  defp status_value(:ok), do: "ok"
  defp status_value({:loading, _info}), do: "loading"
  defp status_value({:error, _reason}), do: "error"
  defp status_value(_), do: nil

  defp locale(assigns) do
    Map.get(assigns.i18n || %{}, :locale) || Map.get(assigns.i18n || %{}, "locale")
  end
end
