defmodule JsonFormsLV.Phoenix.Cells.NumberInput do
  @moduledoc """
  Cell renderer for number and integer inputs.
  """

  use Phoenix.Component

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(_uischema, %{"type" => "integer"}, _ctx), do: 10
  def tester(_uischema, %{"type" => "number"}, _ctx), do: 9
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    inputmode = inputmode(assigns.schema)

    change_event = if assigns.binding == :per_input, do: assigns.on_change
    blur_event = assigns.on_blur
    placeholder = placeholder(assigns)
    suggestions = suggestions(assigns)
    datalist_id = if suggestions != [], do: "#{assigns.id}-list"
    autocomplete = autocomplete(assigns)
    slider? = Map.get(assigns.options || %{}, "slider") == true
    {min, max, step} = slider_attrs(assigns.schema)
    locale = locale(assigns)

    value =
      case assigns.value do
        nil -> ""
        _ -> to_string(assigns.value)
      end

    assigns =
      assign(assigns,
        inputmode: inputmode,
        value: value,
        disabled?: disabled?(assigns),
        change_event: change_event,
        blur_event: blur_event,
        placeholder: placeholder,
        suggestions: suggestions,
        datalist_id: datalist_id,
        autocomplete: autocomplete,
        slider?: slider?,
        min: min,
        max: max,
        step: step,
        locale: locale,
        aria_describedby: assigns[:aria_describedby],
        aria_invalid: assigns[:aria_invalid],
        aria_required: assigns[:aria_required]
      )

    ~H"""
    <input
      id={@id}
      name={@path}
      type={if @slider?, do: "range", else: "text"}
      inputmode={@inputmode}
      value={@value}
      placeholder={@placeholder}
      list={@datalist_id}
      autocomplete={@autocomplete}
      min={@min}
      max={@max}
      step={@step}
      lang={@locale}
      disabled={@disabled?}
      aria-describedby={@aria_describedby}
      aria-invalid={@aria_invalid}
      aria-required={@aria_required}
      phx-change={@change_event}
      phx-blur={@blur_event}
      phx-target={@target}
    />
    <%= if @suggestions != [] do %>
      <datalist id={@datalist_id}>
        <%= for suggestion <- @suggestions do %>
          <option value={suggestion}></option>
        <% end %>
      </datalist>
    <% end %>
    """
  end

  defp inputmode(%{"type" => "integer"}), do: "numeric"
  defp inputmode(%{"type" => "number"}), do: "decimal"
  defp inputmode(_), do: "numeric"

  defp disabled?(assigns) do
    not assigns.enabled? or assigns.readonly?
  end

  defp placeholder(assigns) do
    placeholder = Map.get(assigns.options || %{}, "placeholder")
    if is_binary(placeholder), do: placeholder
  end

  defp suggestions(assigns) do
    case Map.get(assigns.options || %{}, "suggestion") do
      list when is_list(list) ->
        list
        |> Enum.map(&to_string/1)
        |> Enum.reject(&(&1 == ""))

      value when is_binary(value) ->
        [value]

      _ ->
        []
    end
  end

  defp autocomplete(assigns) do
    case Map.get(assigns.options || %{}, "autocomplete") do
      true -> "on"
      false -> "off"
      value when is_binary(value) -> value
      _ -> nil
    end
  end

  defp slider_attrs(schema) do
    min = number_attr(schema, "minimum")
    max = number_attr(schema, "maximum")

    step =
      cond do
        is_number(schema["multipleOf"]) -> schema["multipleOf"]
        schema["type"] == "integer" -> 1
        true -> "any"
      end

    {min, max, step}
  end

  defp number_attr(schema, key) do
    case Map.get(schema, key) do
      value when is_integer(value) -> value
      value when is_float(value) -> value
      _ -> nil
    end
  end

  defp locale(assigns) do
    Map.get(assigns.i18n || %{}, :locale) || Map.get(assigns.i18n || %{}, "locale")
  end
end
