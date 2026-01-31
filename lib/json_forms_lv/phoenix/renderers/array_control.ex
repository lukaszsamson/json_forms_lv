defmodule JsonFormsLV.Phoenix.Renderers.ArrayControl do
  @moduledoc """
  Renderer for array controls.
  """

  use Phoenix.Component

  alias JsonFormsLV.{Data, Errors, I18n, Path, Schema}
  alias JsonFormsLV.Phoenix.Cells.EnumOptions
  alias JsonFormsLV.Phoenix.Renderers.Control

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(%{"type" => "Control"}, %{"type" => "array"}, _ctx), do: 30
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    label = resolve_label(assigns)
    description = resolve_description(assigns)
    label = I18n.translate_label(label, assigns.i18n, assigns.ctx)
    description = I18n.translate_description(description, assigns.i18n, assigns.ctx)
    add_aria_label = if label, do: "Add #{label}", else: "Add item"
    items = array_items(assigns)
    item_ids = array_item_ids(assigns, items)
    item_labels = item_labels(assigns, items)
    show_sort? = Map.get(assigns.options, "showSortButtons") == true
    choice_select = if choice_array?(assigns.schema), do: choice_select(assigns)
    stream_name = stream_name(assigns)
    stream_entries = stream_entries(assigns, stream_name)
    stream? = stream_name != nil and is_map(assigns.streams)

    assigns =
      assign(assigns,
        label: label,
        description: description,
        items: items,
        item_ids: item_ids,
        item_labels: item_labels,
        show_sort?: show_sort?,
        choice_select: choice_select,
        add_aria_label: add_aria_label,
        stream?: stream?,
        stream_entries: stream_entries
      )

    ~H"""
    <%= if @visible? do %>
      <div id={@id} data-jf-control data-jf-array class="jf-control jf-array">
        <%= if @label do %>
          <label class="jf-label">{@label}</label>
        <% end %>

        <%= if @choice_select do %>
          {@choice_select}
        <% else %>
          <div
            id={"#{@id}-items"}
            class="jf-array-items"
            phx-update={if @stream?, do: "stream"}
          >
            <%= if @stream? do %>
              <%= for {dom_id, entry} <- @stream_entries do %>
                <% index = entry.index || 0 %>
                <div id={dom_id} data-jf-array-item class="jf-array-item">
                  <div class="jf-array-item-header">
                    <span class="jf-array-item-label">{@item_labels[index]}</span>
                    <div class="jf-array-item-actions">
                      <button
                        id={"#{@id}-remove-#{index}"}
                        type="button"
                        aria-label={"Remove #{@item_labels[index]}"}
                        phx-click="jf:remove_item"
                        phx-value-path={@path}
                        phx-value-index={index}
                        phx-target={@target}
                        disabled={not @enabled? or @readonly?}
                      >
                        Remove
                      </button>
                      <%= if @show_sort? do %>
                        <button
                          id={"#{@id}-move-up-#{index}"}
                          type="button"
                          aria-label={"Move #{@item_labels[index]} up"}
                          phx-click="jf:move_item"
                          phx-value-path={@path}
                          phx-value-from={index}
                          phx-value-to={index - 1}
                          phx-target={@target}
                          disabled={not @enabled? or @readonly? or index == 0}
                        >
                          Up
                        </button>
                        <button
                          id={"#{@id}-move-down-#{index}"}
                          type="button"
                          aria-label={"Move #{@item_labels[index]} down"}
                          phx-click="jf:move_item"
                          phx-value-path={@path}
                          phx-value-from={index}
                          phx-value-to={index + 1}
                          phx-target={@target}
                          disabled={not @enabled? or @readonly? or index == length(@items) - 1}
                        >
                          Down
                        </button>
                      <% end %>
                    </div>
                  </div>
                  <div class="jf-array-item-body">
                    <%= render_item(assigns, index) %>
                  </div>
                </div>
              <% end %>
            <% else %>
              <%= for {item, index} <- Enum.with_index(@items) do %>
                <div
                  id={item_dom_id(@id, @item_ids, index)}
                  data-jf-array-item
                  class="jf-array-item"
                >
                  <div class="jf-array-item-header">
                    <span class="jf-array-item-label">{@item_labels[index]}</span>
                    <div class="jf-array-item-actions">
                      <button
                        id={"#{@id}-remove-#{index}"}
                        type="button"
                        aria-label={"Remove #{@item_labels[index]}"}
                        phx-click="jf:remove_item"
                        phx-value-path={@path}
                        phx-value-index={index}
                        phx-target={@target}
                        disabled={not @enabled? or @readonly?}
                      >
                        Remove
                      </button>
                      <%= if @show_sort? do %>
                        <button
                          id={"#{@id}-move-up-#{index}"}
                          type="button"
                          aria-label={"Move #{@item_labels[index]} up"}
                          phx-click="jf:move_item"
                          phx-value-path={@path}
                          phx-value-from={index}
                          phx-value-to={index - 1}
                          phx-target={@target}
                          disabled={not @enabled? or @readonly? or index == 0}
                        >
                          Up
                        </button>
                        <button
                          id={"#{@id}-move-down-#{index}"}
                          type="button"
                          aria-label={"Move #{@item_labels[index]} down"}
                          phx-click="jf:move_item"
                          phx-value-path={@path}
                          phx-value-from={index}
                          phx-value-to={index + 1}
                          phx-target={@target}
                          disabled={not @enabled? or @readonly? or index == length(@items) - 1}
                        >
                          Down
                        </button>
                      <% end %>
                    </div>
                  </div>
                  <div class="jf-array-item-body">
                    <%= render_item(assigns, index) %>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>

          <button
            id={"#{@id}-add"}
            type="button"
            aria-label={@add_aria_label}
            phx-click="jf:add_item"
            phx-value-path={@path}
            phx-target={@target}
            disabled={not @enabled? or @readonly?}
          >
            Add item
          </button>
        <% end %>

        <%= if @description do %>
          <p class="jf-description">{@description}</p>
        <% end %>

        <%= if @show_errors? and @errors_for_control != [] do %>
          <ul class="jf-errors">
            <%= for error <- @errors_for_control do %>
              <li>{I18n.translate_error(error, @i18n, @ctx)}</li>
            <% end %>
          </ul>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp choice_select(assigns) do
    options =
      EnumOptions.options(%{
        schema: items_schema(assigns.schema),
        i18n: assigns.i18n,
        ctx: assigns.ctx
      })

    selected = data_value(assigns.data, assigns.path) || []
    selected = if is_list(selected), do: selected, else: []

    aria_required = if assigns.required?, do: "true"
    assigns = assign(assigns, options: options, selected: selected, aria_required: aria_required)

    ~H"""
    <select
      id={@id <> "-choices"}
      name={@path}
      multiple
      disabled={not @enabled? or @readonly?}
      aria-required={@aria_required}
      phx-change={if @binding == :per_input, do: @on_change}
      phx-blur={@on_blur}
      phx-target={@target}
    >
      <%= for option <- @options do %>
        <option value={option.value} selected={option.raw in @selected}>{option.label}</option>
      <% end %>
    </select>
    """
  end

  defp resolve_label(%{uischema: %{"label" => false}}), do: nil
  defp resolve_label(%{uischema: %{"label" => label}}) when is_binary(label), do: label
  defp resolve_label(%{schema: %{"title" => title}}) when is_binary(title), do: title

  defp resolve_label(%{path: path}) when is_binary(path) do
    path
    |> String.split(".", trim: true)
    |> List.last()
    |> humanize()
  end

  defp resolve_label(_), do: nil

  defp resolve_description(%{uischema: %{"options" => %{"description" => description}}})
       when is_binary(description) do
    description
  end

  defp resolve_description(%{schema: %{"description" => description}})
       when is_binary(description),
       do: description

  defp resolve_description(_), do: nil

  defp humanize(nil), do: nil

  defp humanize(segment) do
    segment
    |> String.replace("_", " ")
    |> String.replace(~r/([a-z])([A-Z])/, "\\1 \\2")
    |> String.trim()
    |> String.capitalize()
  end

  defp array_items(assigns) do
    case Data.get(assigns.data, assigns.path) do
      {:ok, items} when is_list(items) -> items
      _ -> []
    end
  end

  defp array_item_ids(assigns, items) do
    ids = Map.get(assigns.state.array_ids || %{}, assigns.path, [])

    if length(ids) == length(items) do
      ids
    else
      if items == [] do
        []
      else
        Enum.map(0..(length(items) - 1), &Integer.to_string/1)
      end
    end
  end

  defp item_dom_id(base_id, ids, index) do
    id = Enum.at(ids, index) || Integer.to_string(index)
    "#{base_id}-item-#{sanitize_id(id)}"
  end

  defp sanitize_id(value) do
    value
    |> String.replace(".", "-")
    |> String.replace(~r/[^A-Za-z0-9_-]/, "-")
  end

  defp item_label(options, item, index) do
    label_prop = Map.get(options || %{}, "elementLabelProp")

    cond do
      is_binary(label_prop) and is_map(item) and Map.has_key?(item, label_prop) ->
        item
        |> Map.get(label_prop)
        |> to_string()

      true ->
        "Item #{index + 1}"
    end
  end

  defp item_labels(assigns, items) do
    options = assigns.options || %{}

    items
    |> Enum.with_index()
    |> Map.new(fn {item, index} -> {index, item_label(options, item, index)} end)
  end

  defp stream_name(assigns) do
    config = assigns.config || %{}

    stream_arrays? =
      Map.get(config, :stream_arrays, false) || Map.get(config, "stream_arrays", false)

    stream_names = Map.get(config, :stream_names, %{}) || Map.get(config, "stream_names", %{})

    if stream_arrays? do
      Map.get(stream_names, assigns.path)
    end
  end

  defp stream_entries(_assigns, nil), do: []

  defp stream_entries(assigns, stream_name) do
    streams = assigns.streams || %{}

    case Map.get(streams, stream_name) do
      nil -> []
      entries -> entries
    end
  end

  defp render_item(assigns, index) do
    schema = item_schema(assigns.schema, index)
    item_path = Path.join(assigns.path, Integer.to_string(index))
    assigns = assign(assigns, item_schema: schema, item_path: item_path, item_index: index)

    if object_schema?(schema) do
      props = detail_property_paths(assigns, schema)
      assigns = assign(assigns, props: props)

      ~H"""
      <%= for prop_path <- @props do %>
        <%= if is_map(@item_schema) do %>
          <%= case Schema.resolve_at_data_path(@item_schema, prop_path) do %>
            <% {:ok, prop_schema} -> %>
              <%=
                render_control(
                  assigns,
                  %{"type" => "Control"},
                  prop_schema,
                  Path.join(@item_path, prop_path)
                )
              %>
            <% {:error, _} -> %>
          <% end %>
        <% end %>
      <% end %>
      """
    else
      label = "Item #{index + 1}"
      assigns = assign(assigns, item_label: label)

      ~H"""
      <%=
        render_control(
          assigns,
          %{"type" => "Control", "label" => @item_label},
          @item_schema,
          @item_path
        )
      %>
      """
    end
  end

  defp render_control(assigns, uischema, schema, path) do
    value = data_value(assigns.data, path)
    instance_path = Path.data_path_to_instance_path(path)
    errors_for_control = Errors.errors_for_control(assigns.state, path)

    show_errors? =
      Errors.show_validator_errors?(assigns.state, path) ||
        Errors.has_additional_errors?(errors_for_control)

    ctx =
      assigns.ctx
      |> Map.merge(%{
        schema: schema,
        uischema: uischema,
        path: path,
        instance_path: instance_path
      })

    control_assigns =
      assigns
      |> assign(%{
        id: "#{assigns.id}-#{sanitize_id(path)}",
        uischema: uischema,
        schema: schema,
        root_schema: assigns.root_schema,
        data: assigns.data,
        path: path,
        instance_path: instance_path,
        value: value,
        visible?: true,
        enabled?: assigns.enabled?,
        readonly?: assigns.readonly?,
        options: Map.get(uischema, "options", %{}),
        i18n: assigns.i18n,
        config: assigns.config,
        ctx: ctx,
        errors_for_control: errors_for_control,
        show_errors?: show_errors?,
        registry: assigns.registry,
        binding: assigns.binding,
        on_change: assigns.on_change,
        on_blur: assigns.on_blur,
        target: assigns.target
      })

    Control.render(control_assigns)
  end

  defp data_value(data, path) do
    case Data.get(data, path) do
      {:ok, value} -> value
      {:error, _} -> nil
    end
  end

  defp item_schema(%{"items" => items}, index) when is_list(items) and is_integer(index) do
    cond do
      index >= 0 and index < length(items) -> Enum.at(items, index)
      true -> nil
    end
  end

  defp item_schema(%{"items" => items}, _index) when is_map(items), do: items
  defp item_schema(_schema, _index), do: nil

  defp items_schema(%{"items" => items}) when is_map(items), do: items
  defp items_schema(_schema), do: %{}

  defp object_schema?(%{"type" => "object"}), do: true
  defp object_schema?(%{"properties" => props}) when is_map(props), do: true
  defp object_schema?(_schema), do: false

  defp choice_array?(%{"items" => %{"enum" => enum}}) when is_list(enum), do: true
  defp choice_array?(%{"items" => %{"oneOf" => one_of}}) when is_list(one_of), do: true
  defp choice_array?(_schema), do: false

  defp detail_property_paths(assigns, schema) do
    case Map.get(assigns.options || %{}, "detail") do
      "DEFAULT" ->
        default_property_paths(schema)

      "GENERATED" ->
        generated_property_paths(schema)

      "REGISTERED" ->
        registered_property_paths(assigns, schema)

      %{"elements" => elements} when is_list(elements) ->
        elements
        |> Enum.flat_map(&detail_control_path/1)
        |> Enum.uniq()
        |> case do
          [] -> default_property_paths(schema)
          paths -> paths
        end

      _ ->
        default_property_paths(schema)
    end
  end

  defp detail_control_path(%{"type" => "Control", "scope" => scope}) when is_binary(scope) do
    path = Path.schema_pointer_to_data_path(scope)
    if path == "", do: [], else: [path]
  end

  defp detail_control_path(_), do: []

  defp default_property_paths(schema) do
    (schema || %{})
    |> Map.get("properties", %{})
    |> Map.keys()
    |> Enum.sort()
  end

  defp generated_property_paths(schema), do: default_property_paths(schema)

  defp registered_property_paths(assigns, schema) do
    key =
      Map.get(assigns.options || %{}, "detailKey") ||
        Map.get(assigns.options || %{}, "detailId")

    registry = detail_registry(assigns)

    cond do
      is_binary(key) and is_map(registry) ->
        case Map.get(registry, key) do
          %{"elements" => elements} when is_list(elements) ->
            elements
            |> Enum.flat_map(&detail_control_path/1)
            |> Enum.uniq()
            |> case do
              [] -> default_property_paths(schema)
              paths -> paths
            end

          _ ->
            default_property_paths(schema)
        end

      true ->
        default_property_paths(schema)
    end
  end

  defp detail_registry(assigns) do
    config = assigns.config || %{}
    Map.get(config, :detail_registry) || Map.get(config, "detail_registry") || %{}
  end
end
