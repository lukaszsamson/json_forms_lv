defmodule JsonFormsLV.Phoenix.Renderers.CombinatorControl do
  @moduledoc """
  Renderer for oneOf/anyOf/allOf combinator controls.
  """

  use Phoenix.Component

  alias JsonFormsLV.{Data, Errors, I18n, Path, Schema}
  alias JsonFormsLV.Phoenix.Renderers.Control

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(%{"type" => "Control"}, %{"oneOf" => one_of}, _ctx) when is_list(one_of), do: 40
  def tester(%{"type" => "Control"}, %{"anyOf" => any_of}, _ctx) when is_list(any_of), do: 40
  def tester(%{"type" => "Control"}, %{"allOf" => all_of}, _ctx) when is_list(all_of), do: 40
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    {label, label_visible?} = resolve_label(assigns)
    description = resolve_description(assigns)
    label = I18n.translate_label(label, assigns.i18n, assigns.ctx)
    description = I18n.translate_description(description, assigns.i18n, assigns.ctx)

    {kind, schemas} = combinator_schemas(assigns.schema)
    options = schema_options(schemas)
    selection = combinator_selection(assigns, kind, length(options))

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

    assigns =
      assign(assigns,
        label: label,
        label_visible?: label_visible?,
        description: description,
        description_class: description_class,
        combinator_kind: kind,
        combinator_options: options,
        combinator_selection: selection
      )

    ~H"""
    <%= if @visible? do %>
      <div id={@id} data-jf-control data-jf-combinator class="jf-control jf-combinator">
        <%= if @label_visible? and @label do %>
          <label class="jf-label">{@label}</label>
        <% end %>

        <%= if @combinator_kind in [:one_of, :any_of] do %>
          <div class="jf-combinator-select">
            <select
              id={"#{@id}-combinator"}
              name="selection"
              multiple={@combinator_kind == :any_of}
              phx-change="jf:select_combinator"
              phx-target={@target}
              phx-value-path={@path}
            >
              <%= for {option, index} <- Enum.with_index(@combinator_options) do %>
                <option
                  value={index}
                  selected={selected_option?(index, @combinator_selection)}
                >
                  {option.label}
                </option>
              <% end %>
            </select>
          </div>
        <% end %>

        <div class="jf-combinator-body">
          <%= for {schema, index} <- Enum.with_index(@combinator_options) do %>
            <%= if render_schema?(index, @combinator_kind, @combinator_selection) do %>
              <div class="jf-combinator-section">
                <%= if @combinator_kind == :all_of do %>
                  <div class="jf-combinator-heading">{schema.label}</div>
                <% end %>
                <%= render_schema(assigns, schema.schema) %>
              </div>
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

  defp render_schema(assigns, schema) do
    data_value = data_value(assigns.data, assigns.path)

    if object_schema?(schema) do
      props =
        schema
        |> Map.get("properties", %{})
        |> Map.keys()
        |> Enum.sort()

      assigns = assign(assigns, props: props, item_schema: schema, item_data: data_value)

      ~H"""
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
              render_control(
                assigns,
                %{"type" => "Control"},
                prop_schema,
                Path.join(@path, prop_path)
              )
            %>
          <% {:error, _} -> %>
        <% end %>
      <% end %>
      """
    else
      assigns = assign(assigns, item_schema: schema)

      ~H"""
      <%=
        render_control(
          assigns,
          %{"type" => "Control"},
          @item_schema,
          @path
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

  defp combinator_schemas(schema) do
    cond do
      is_list(schema["oneOf"]) -> {:one_of, schema["oneOf"]}
      is_list(schema["anyOf"]) -> {:any_of, schema["anyOf"]}
      is_list(schema["allOf"]) -> {:all_of, schema["allOf"]}
      true -> {:one_of, []}
    end
  end

  defp schema_options(schemas) do
    schemas
    |> Enum.with_index()
    |> Enum.map(fn {schema, index} ->
      label =
        Map.get(schema, "title") ||
          Map.get(schema, "label") ||
          "Option #{index + 1}"

      %{label: label, schema: schema}
    end)
  end

  defp combinator_selection(assigns, :one_of, option_count) do
    selection = Map.get(assigns.state.combinator_state || %{}, assigns.path)

    cond do
      is_integer(selection) and selection >= 0 and selection < option_count -> selection
      option_count > 0 -> 0
      true -> nil
    end
  end

  defp combinator_selection(assigns, :any_of, option_count) do
    selection = Map.get(assigns.state.combinator_state || %{}, assigns.path)

    cond do
      is_list(selection) and selection != [] ->
        selection

      option_count > 0 ->
        [0]

      true ->
        []
    end
  end

  defp combinator_selection(_assigns, :all_of, _option_count), do: []

  defp render_schema?(index, :one_of, selection), do: index == selection
  defp render_schema?(index, :any_of, selection), do: index in selection
  defp render_schema?(_index, :all_of, _selection), do: true

  defp selected_option?(index, selection) when is_list(selection), do: index in selection
  defp selected_option?(index, selection), do: index == selection

  defp object_schema?(%{"type" => "object"}), do: true
  defp object_schema?(%{"properties" => props}) when is_map(props), do: true
  defp object_schema?(_schema), do: false

  defp sanitize_id(value) do
    value
    |> to_string()
    |> String.replace(".", "-")
    |> String.replace(~r/[^A-Za-z0-9_-]/, "-")
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
    |> String.replace(~r/([a-z])([A-Z])/, "\1 \2")
    |> String.trim()
    |> String.capitalize()
  end
end
