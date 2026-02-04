defmodule JsonFormsLV.Phoenix.Renderers.Control do
  @moduledoc """
  Renderer for Control UISchema elements.
  """

  use Phoenix.Component

  alias JsonFormsLV.{Data, Dispatch, Errors, I18n, Path, Schema}

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(%{"type" => "Control"}, _schema, _ctx), do: 10
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    # Check if schema is object type - render nested controls instead of a cell
    if object_schema?(assigns.schema) do
      render_object(assigns)
    else
      render_cell(assigns)
    end
  end

  defp render_cell(assigns) do
    {label, label_visible?} = resolve_label(assigns)
    description = resolve_description(assigns)
    label = I18n.translate_label(label, assigns.i18n, assigns.ctx)
    description = I18n.translate_description(description, assigns.i18n, assigns.ctx)
    input_id = "#{assigns.id}-input"
    description_id = if description, do: "#{assigns.id}-description"

    errors_id =
      if assigns.show_errors? and assigns.errors_for_control != [], do: "#{assigns.id}-errors"

    radio? = Map.get(assigns.options, "format") == "radio"
    boolean? = Map.get(assigns.schema, "type") == "boolean"
    toggle? = Map.get(assigns.options, "toggle") == true
    # For boolean (checkbox), render label inline after the input
    inline_label? = boolean? and not toggle?
    show_label? = (label_visible? and label) && not radio? && not inline_label?
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

    aria_describedby =
      [description_id, errors_id]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")

    aria_describedby = if aria_describedby == "", do: nil, else: aria_describedby
    aria_invalid = if errors_id, do: "true"
    aria_required = if assigns.required?, do: "true"

    assigns =
      assign(assigns,
        label: label,
        description: description,
        description_class: description_class,
        input_id: input_id,
        description_id: description_id,
        errors_id: errors_id,
        aria_describedby: aria_describedby,
        aria_invalid: aria_invalid,
        aria_required: aria_required,
        show_label?: show_label?,
        inline_label?: inline_label?
      )

    cell_entry =
      Dispatch.pick_renderer(
        assigns.uischema,
        assigns.schema,
        assigns.registry,
        assigns.ctx,
        :cell
      )

    {cell_module, _opts} = cell_entry || {JsonFormsLV.Phoenix.Cells.StringInput, []}

    assigns = assign(assigns, cell_module: cell_module)

    ~H"""
    <%= if @visible? do %>
      <div id={@id} data-jf-control class="jf-control">
        <%= if @show_label? do %>
          <label for={@input_id} class="jf-label">{@label}</label>
        <% end %>
        <%= if @inline_label? do %>
          <div class="jf-checkbox-wrapper">
            <.dynamic_component
              module={@cell_module}
              function={:render}
              id={@input_id}
              uischema={@uischema}
              schema={@schema}
              root_schema={@root_schema}
              data={@data}
              path={@path}
              instance_path={@instance_path}
              value={@value}
              enabled?={@enabled?}
              readonly?={@readonly?}
              options={@options}
              i18n={@i18n}
              config={@config}
              ctx={@ctx}
              binding={@binding}
              on_change={@on_change}
              on_blur={@on_blur}
              target={@target}
              aria_describedby={@aria_describedby}
              aria_invalid={@aria_invalid}
              aria_required={@aria_required}
              label={@label}
              required?={@required?}
            />
            <label for={@input_id} class="jf-checkbox-label">{@label}</label>
          </div>
        <% else %>
          <.dynamic_component
            module={@cell_module}
            function={:render}
            id={@input_id}
            uischema={@uischema}
            schema={@schema}
            root_schema={@root_schema}
            data={@data}
            path={@path}
            instance_path={@instance_path}
            value={@value}
            enabled?={@enabled?}
            readonly?={@readonly?}
            options={@options}
            i18n={@i18n}
            config={@config}
            ctx={@ctx}
            binding={@binding}
            on_change={@on_change}
            on_blur={@on_blur}
            target={@target}
            aria_describedby={@aria_describedby}
            aria_invalid={@aria_invalid}
            aria_required={@aria_required}
            label={@label}
            required?={@required?}
          />
        <% end %>
        <%= if @description do %>
          <p id={@description_id} class={@description_class}>{@description}</p>
        <% end %>
        <%= if @show_errors? and @errors_for_control != [] do %>
          <ul id={@errors_id} class="jf-errors" role="alert">
            <%= for error <- @errors_for_control do %>
              <li>{I18n.translate_error(error, @i18n, @ctx)}</li>
            <% end %>
          </ul>
        <% end %>
      </div>
    <% end %>
    """
  end

  attr(:module, :atom, required: true)
  attr(:function, :atom, required: true)
  attr(:id, :string, required: true)
  attr(:uischema, :map, required: true)
  attr(:schema, :map, required: true)
  attr(:root_schema, :map, required: true)
  attr(:data, :any, required: true)
  attr(:path, :string, required: true)
  attr(:instance_path, :string, required: true)
  attr(:value, :any, required: true)
  attr(:enabled?, :boolean, required: true)
  attr(:readonly?, :boolean, required: true)
  attr(:options, :map, required: true)
  attr(:i18n, :map, required: true)
  attr(:config, :map, required: true)
  attr(:ctx, :map, required: true)
  attr(:binding, :atom, required: true)
  attr(:on_change, :string, required: true)
  attr(:on_blur, :string, required: true)
  attr(:target, :any, default: nil)
  attr(:aria_describedby, :string, default: nil)
  attr(:aria_invalid, :string, default: nil)
  attr(:aria_required, :string, default: nil)
  attr(:label, :string, default: nil)
  attr(:required?, :boolean, default: false)

  defp dynamic_component(assigns) do
    {mod, assigns} = Map.pop(assigns, :module)
    {func, assigns} = Map.pop(assigns, :function)
    apply(mod, func, [assigns])
  end

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
    |> String.replace(~r/([a-z])([A-Z])/, "\\1 \\2")
    |> String.trim()
    |> String.capitalize()
  end

  # Object schema handling - render nested controls for each property
  defp object_schema?(%{"type" => "object"}), do: true
  defp object_schema?(%{"properties" => props}) when is_map(props), do: true
  defp object_schema?(_schema), do: false

  defp render_object(assigns) do
    {label, label_visible?} = resolve_label(assigns)
    description = resolve_description(assigns)
    label = I18n.translate_label(label, assigns.i18n, assigns.ctx)
    description = I18n.translate_description(description, assigns.i18n, assigns.ctx)

    hide_required? = Map.get(assigns.options, "hideRequiredAsterisk") == true
    label = if (assigns.required? and label) && not hide_required?, do: label <> " *", else: label

    show_unfocused_description? = Map.get(assigns.options, "showUnfocusedDescription") != false

    description_class =
      if show_unfocused_description? do
        "jf-description"
      else
        "jf-description jf-description--focus"
      end

    props =
      assigns.schema
      |> Map.get("properties", %{})
      |> Map.keys()
      |> Enum.sort()

    data_value = get_data_value(assigns.data, assigns.path)

    assigns =
      assign(assigns,
        label: label,
        label_visible?: label_visible?,
        description: description,
        description_class: description_class,
        props: props,
        item_schema: assigns.schema,
        item_data: data_value
      )

    ~H"""
    <%= if @visible? do %>
      <div id={@id} data-jf-control data-jf-object class="jf-control jf-object-control">
        <%= if @label_visible? and @label do %>
          <label class="jf-label">{@label}</label>
        <% end %>
        <div class="jf-object-properties">
          <%= for prop_path <- @props do %>
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
                  render_nested_control(
                    assigns,
                    %{"type" => "Control"},
                    prop_schema,
                    Path.join(@path, prop_path)
                  )
                %>
              <% {:error, _} -> %>
            <% end %>
          <% end %>
        </div>
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

  defp render_nested_control(assigns, uischema, schema, path) do
    value = get_data_value(assigns.data, path)
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

    render(control_assigns)
  end

  defp get_data_value(data, path) do
    case Data.get(data, path) do
      {:ok, value} -> value
      {:error, _} -> nil
    end
  end

  defp sanitize_id(value) do
    value
    |> to_string()
    |> String.replace(".", "-")
    |> String.replace(~r/[^A-Za-z0-9_-]/, "-")
  end
end
