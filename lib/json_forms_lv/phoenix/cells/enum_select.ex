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
    raw_value = assigns.value
    allow_empty? = allow_empty_option?(assigns)
    empty_label = empty_label(assigns)
    autocomplete? = autocomplete_mode?(assigns)
    autocomplete = autocomplete(assigns)
    list_id = if autocomplete?, do: "#{assigns.id}-list"
    placeholder = if allow_empty?, do: empty_label

    assigns =
      assigns
      |> assign(:disabled?, disabled?(assigns))
      |> assign(:options, EnumOptions.options(assigns))
      |> assign(:value, EnumOptions.encode_value(raw_value))
      |> assign(:raw_value, raw_value)
      |> assign(:allow_empty?, allow_empty?)
      |> assign(:empty_label, empty_label)
      |> assign(:change_event, change_event)
      |> assign(:blur_event, blur_event)
      |> assign(:autocomplete?, autocomplete?)
      |> assign(:autocomplete, autocomplete)
      |> assign(:list_id, list_id)
      |> assign(:placeholder, placeholder)
      |> assign(:aria_describedby, assigns[:aria_describedby])
      |> assign(:aria_invalid, assigns[:aria_invalid])
      |> assign(:aria_required, assigns[:aria_required])

    ~H"""
    <%= if @autocomplete? do %>
      <input
        id={@id}
        name={@path}
        type="text"
        value={@value}
        list={@list_id}
        placeholder={@placeholder}
        autocomplete={@autocomplete}
        disabled={@disabled?}
        aria-describedby={@aria_describedby}
        aria-invalid={@aria_invalid}
        aria-required={@aria_required}
        phx-change={@change_event}
        phx-blur={@blur_event}
        phx-target={@target}
      />
      <datalist id={@list_id}>
        <%= if @allow_empty? do %>
          <option value="">{@empty_label}</option>
        <% end %>
        <%= for option <- @options do %>
          <option value={option.value}>{option.label}</option>
        <% end %>
      </datalist>
    <% else %>
      <select
        id={@id}
        name={@path}
        disabled={@disabled?}
        aria-describedby={@aria_describedby}
        aria-invalid={@aria_invalid}
        aria-required={@aria_required}
        phx-change={@change_event}
        phx-blur={@blur_event}
        phx-target={@target}
      >
        <%= if @allow_empty? do %>
          <option value="" selected={@raw_value in [nil, ""]}>{@empty_label}</option>
        <% end %>
        <%= for option <- @options do %>
          <option value={option.value} selected={option.raw == @raw_value}>{option.label}</option>
        <% end %>
      </select>
    <% end %>
    """
  end

  defp disabled?(assigns) do
    not assigns.enabled? or assigns.readonly?
  end

  defp allow_empty_option?(assigns) do
    not required?(assigns) or nullable?(assigns.schema)
  end

  defp empty_label(assigns) do
    placeholder = Map.get(assigns.options || %{}, "placeholder")

    if is_binary(placeholder) and placeholder != "" do
      placeholder
    else
      "Select..."
    end
  end

  defp autocomplete_mode?(assigns) do
    case Map.get(assigns.options || %{}, "autocomplete") do
      true -> true
      value when is_binary(value) -> value != "off"
      _ -> false
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

  defp nullable?(%{"type" => types}) when is_list(types), do: "null" in types
  defp nullable?(_schema), do: false

  defp required?(assigns) do
    case Map.get(assigns, :required?) do
      value when is_boolean(value) ->
        value

      _ ->
        with path when is_binary(path) <- assigns.path,
             segments when segments != [] <- JsonFormsLV.Path.parse_data_path(path),
             {leaf, parent_segments} when not is_nil(leaf) <- List.pop_at(segments, -1),
             leaf_key when is_binary(leaf_key) <- segment_key(leaf),
             parent_path <- segments_to_path(parent_segments),
             {:ok, parent_schema} <-
               JsonFormsLV.Schema.resolve_at_data_path(assigns.root_schema, parent_path),
             required when is_list(required) <- Map.get(parent_schema, "required") do
          leaf_key in required
        else
          _ -> false
        end
    end
  end

  defp segment_key(segment) when is_binary(segment), do: segment
  defp segment_key(_segment), do: nil

  defp segments_to_path([]), do: ""

  defp segments_to_path(segments) do
    segments
    |> Enum.map(&to_string/1)
    |> Enum.join(".")
  end
end
