defmodule JsonFormsLV.Phoenix.Renderers.ListWithDetail do
  @moduledoc """
  Renderer for ListWithDetail UISchema elements.
  """

  use Phoenix.Component

  alias JsonFormsLV.{Data, Errors, I18n, Path, Schema}
  alias JsonFormsLV.Phoenix.Renderers.Control

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(%{"type" => "ListWithDetail"}, %{"type" => "array"}, _ctx), do: 35
  def tester(%{"type" => "ListWithDetail"}, %{"items" => _items}, _ctx), do: 35
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    {label, label_visible?} = resolve_label(assigns)
    description = resolve_description(assigns)
    label = I18n.translate_label(label, assigns.i18n, assigns.ctx)
    description = I18n.translate_description(description, assigns.i18n, assigns.ctx)
    items = array_items(assigns)
    item_ids = array_item_ids(assigns, items)
    item_labels = item_labels(assigns, items)
    show_sort? = Map.get(assigns.options, "showSortButtons") == true
    hide_required? = Map.get(assigns.options, "hideRequiredAsterisk") == true
    label = if (assigns.required? and label) && not hide_required?, do: label <> " *", else: label

    show_unfocused_description? =
      Map.get(assigns.options, "showUnfocusedDescription") != false

    description_class =
      if show_unfocused_description? do
        "jf-description"
      else
        "jf-description jf-description--focus"
      end

    default_open_index = Map.get(assigns.options, "defaultOpenIndex", 0)

    assigns =
      assign(assigns,
        label: label,
        label_visible?: label_visible?,
        description: description,
        description_class: description_class,
        items: items,
        item_ids: item_ids,
        item_labels: item_labels,
        show_sort?: show_sort?,
        default_open_index: default_open_index
      )

    ~H"""
    <%= if @visible? do %>
      <div id={@id} data-jf-control data-jf-list-detail class="jf-control jf-list-detail">
        <%= if @label_visible? and @label do %>
          <label class="jf-label">{@label}</label>
        <% end %>

        <div class="jf-list-detail-items">
          <%= for {item, index} <- Enum.with_index(@items) do %>
            <details
              id={item_dom_id(@id, @item_ids, index)}
              class="jf-list-detail-item"
              open={index == @default_open_index}
              phx-hook="JFPreserveOpen"
            >
              <summary class="jf-list-detail-summary">
                <span class="jf-list-detail-label">{@item_labels[index]}</span>
                <span class="jf-list-detail-actions">
                  <button
                    id={"#{@id}-remove-#{index}"}
                    type="button"
                    tabindex="0"
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
                      tabindex="0"
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
                      tabindex="0"
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
                </span>
              </summary>
              <div class="jf-list-detail-body">
                <%= render_item(assigns, index) %>
              </div>
            </details>
          <% end %>
        </div>

        <button
          id={"#{@id}-add"}
          type="button"
          tabindex="0"
          aria-label={if @label, do: "Add #{@label}", else: "Add item"}
          phx-click="jf:add_item"
          phx-value-path={@path}
          phx-target={@target}
          disabled={not @enabled? or @readonly?}
        >
          Add item
        </button>

        <%= if @description do %>
          <p class={@description_class}>{@description}</p>
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

  defp render_item(assigns, index) do
    schema = item_schema(assigns.schema, index)
    item_path = Path.join(assigns.path, Integer.to_string(index))
    item_data = data_value(assigns.data, item_path)

    assigns =
      assign(assigns,
        item_schema: schema,
        item_path: item_path,
        item_index: index,
        item_data: item_data
      )

    if object_schema?(schema) do
      props = detail_property_paths(assigns, schema)
      assigns = assign(assigns, props: props)

      ~H"""
      <%= for prop_path <- @props do %>
        <%= if is_map(@item_schema) do %>
          <%=
            case Schema.resolve_at_data_path(
                   @item_schema,
                   prop_path,
                   @item_data,
                   @state.validator,
                   @state.validator_opts
                 ) do
          %>
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
    value = if write_only?(schema, assigns.state), do: nil, else: value
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
    |> to_string()
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

  defp item_schema(%{"items" => items}, index) when is_list(items) and is_integer(index) do
    cond do
      index >= 0 and index < length(items) -> Enum.at(items, index)
      true -> nil
    end
  end

  defp item_schema(%{"items" => items}, _index) when is_map(items), do: items
  defp item_schema(_schema, _index), do: nil

  defp object_schema?(%{"type" => "object"}), do: true
  defp object_schema?(%{"properties" => props}) when is_map(props), do: true
  defp object_schema?(_schema), do: false

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
        |> detail_control_paths()
        |> case do
          [] -> default_property_paths(schema)
          paths -> paths
        end

      _ ->
        default_property_paths(schema)
    end
  end

  defp detail_control_paths(elements) do
    elements
    |> Enum.flat_map(&detail_control_path/1)
    |> Enum.uniq()
  end

  defp detail_control_path(%{"type" => "Control", "scope" => scope}) when is_binary(scope) do
    path = Path.schema_pointer_to_data_path(scope)
    if path == "", do: [], else: [path]
  end

  defp detail_control_path(%{"elements" => elements}) when is_list(elements) do
    detail_control_paths(elements)
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

  defp data_value(data, path) do
    case Data.get(data, path) do
      {:ok, value} -> value
      {:error, _} -> nil
    end
  end

  defp write_only?(%{"writeOnly" => true}, %{submitted: true}), do: true
  defp write_only?(_schema, _state), do: false

  defp resolve_label(%{uischema: %{"label" => false}}), do: {nil, false}
  defp resolve_label(%{uischema: %{"label" => %{"show" => false}}}), do: {nil, false}

  defp resolve_label(%{uischema: %{"label" => %{"show" => true, "text" => text}}})
       when is_binary(text),
       do: {text, true}

  defp resolve_label(%{uischema: %{"label" => label}}) when is_binary(label), do: {label, true}
  defp resolve_label(%{schema: %{"title" => title}}) when is_binary(title), do: {title, true}

  defp resolve_label(%{path: path}) when is_binary(path) do
    label =
      path
      |> String.split(".", trim: true)
      |> List.last()
      |> humanize()

    {label, true}
  end

  defp resolve_label(_), do: {nil, true}

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
    |> String.replace(~r/([a-z])([A-Z])/, "\1 \2")
    |> String.trim()
    |> String.capitalize()
  end
end
