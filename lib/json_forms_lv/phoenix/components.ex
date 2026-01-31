defmodule JsonFormsLV.Phoenix.Components do
  @moduledoc """
  Phoenix function components for rendering JSON Forms.
  """

  use Phoenix.Component

  alias JsonFormsLV.{Data, Dispatch, Errors, Limits, Path, Registry, Schema, State}

  attr(:id, :string, required: true)
  attr(:schema, :map, required: true)
  attr(:uischema, :map, required: true)
  attr(:data, :any, required: true)
  attr(:state, :any, default: nil)
  attr(:context, :map, default: %{})
  attr(:validation_mode, :atom, default: :validate_and_show)
  attr(:additional_errors, :list, default: [])
  attr(:readonly, :boolean, default: false)
  attr(:i18n, :map, default: %{})
  attr(:binding, :atom, default: :per_input)
  attr(:wrap_form, :boolean, default: true)
  attr(:target, :any, default: nil)
  attr(:renderers, :list, default: [])
  attr(:control_renderers, :list, default: [])
  attr(:layout_renderers, :list, default: [])
  attr(:cells, :list, default: [])
  attr(:opts, :map, default: %{})
  attr(:streams, :map, default: nil)
  attr(:on_change, :string, default: "jf:change")
  attr(:on_blur, :string, default: "jf:blur")
  attr(:on_submit, :string, default: "jf:submit")

  @doc """
  Render a JSON Forms UI from schema, uischema, and data.

  Use `state={@state}` to pass a precomputed `JsonFormsLV.State` from your LiveView.
  For a self-contained integration, use `JsonFormsLV.Phoenix.LiveComponent`.

  Use `wrap_form={false}` when you want to supply your own `<.form>` wrapper.

  ## Examples

      <.json_forms
        id="profile-form"
        schema={@schema}
        uischema={@uischema}
        data={@data}
      />
  """
  def json_forms(assigns) do
    assigns =
      assigns
      |> ensure_state()
      |> ensure_registry()
      |> ensure_form()

    ~H"""
    <%= if @wrap_form do %>
      <.form
        for={@form}
        id={@id}
        phx-change={if @binding == :form_level, do: @on_change}
        phx-submit={@on_submit}
        phx-target={@target}
      >
        <.dispatch
          state={@state}
          registry={@registry}
          uischema={@uischema}
          data={@data}
          form_id={@id}
          config={@opts}
          binding={@binding}
          streams={@streams}
          element_path={[]}
          on_change={@on_change}
          on_blur={@on_blur}
          on_submit={@on_submit}
          target={@target}
          context={@context}
        />
      </.form>
    <% else %>
      <.dispatch
        state={@state}
        registry={@registry}
        uischema={@uischema}
        data={@data}
        form_id={@id}
        config={@opts}
        binding={@binding}
        streams={@streams}
        element_path={[]}
        on_change={@on_change}
        on_blur={@on_blur}
        on_submit={@on_submit}
        target={@target}
        context={@context}
      />
    <% end %>
    """
  end

  attr(:state, :any, required: true)
  attr(:registry, :any, required: true)
  attr(:uischema, :map, required: true)
  attr(:data, :any, required: true)
  attr(:form_id, :string, required: true)
  attr(:binding, :atom, default: :per_input)
  attr(:streams, :map, default: nil)
  attr(:path, :string, default: "")
  attr(:element_path, :list, default: [])
  attr(:depth, :integer, default: 0)
  attr(:on_change, :string, required: true)
  attr(:on_blur, :string, required: true)
  attr(:on_submit, :string, required: true)
  attr(:target, :any, default: nil)
  attr(:config, :map, default: %{})
  attr(:context, :map, default: %{})
  attr(:parent_visible?, :boolean, default: true)
  attr(:parent_enabled?, :boolean, default: true)

  def dispatch(assigns) do
    assigns = build_dispatch_assigns(assigns)
    apply(assigns.renderer, :render, [assigns.renderer_assigns])
  end

  defp ensure_state(%{state: %State{}} = assigns) do
    state =
      assigns.state
      |> Map.put(:data, assigns.data)
      |> Map.put(:readonly, assigns.readonly)
      |> Map.put(:i18n, assigns.i18n)

    assign(assigns, :state, state)
  end

  defp ensure_state(assigns) do
    opts = merge_config(%{}, assigns.opts)

    state = %State{
      schema: assigns.schema,
      uischema: assigns.uischema,
      data: assigns.data,
      opts: opts,
      validation_mode: assigns.validation_mode,
      additional_errors: assigns.additional_errors,
      readonly: assigns.readonly,
      i18n: assigns.i18n
    }

    assign(assigns, :state, state)
  end

  defp ensure_registry(assigns) do
    custom =
      Registry.new(
        control_renderers: assigns.control_renderers ++ assigns.renderers,
        layout_renderers: assigns.layout_renderers ++ assigns.renderers,
        cell_renderers: assigns.cells
      )

    registry = Registry.merge(custom, default_registry())
    assign(assigns, :registry, registry)
  end

  defp ensure_form(assigns) do
    form = to_form(%{}, as: :jf)
    assign(assigns, :form, form)
  end

  defp default_registry do
    Registry.new(
      control_renderers: [
        JsonFormsLV.Phoenix.Renderers.ArrayControl,
        JsonFormsLV.Phoenix.Renderers.Control
      ],
      layout_renderers: [
        JsonFormsLV.Phoenix.Renderers.Label,
        JsonFormsLV.Phoenix.Renderers.Categorization,
        JsonFormsLV.Phoenix.Renderers.Category,
        JsonFormsLV.Phoenix.Renderers.Group,
        JsonFormsLV.Phoenix.Renderers.VerticalLayout,
        JsonFormsLV.Phoenix.Renderers.HorizontalLayout
      ],
      cell_renderers: [
        JsonFormsLV.Phoenix.Cells.EnumRadio,
        JsonFormsLV.Phoenix.Cells.EnumSelect,
        JsonFormsLV.Phoenix.Cells.DateInput,
        JsonFormsLV.Phoenix.Cells.DateTimeInput,
        JsonFormsLV.Phoenix.Cells.MultilineInput,
        JsonFormsLV.Phoenix.Cells.BooleanInput,
        JsonFormsLV.Phoenix.Cells.NumberInput,
        JsonFormsLV.Phoenix.Cells.StringInput
      ]
    )
  end

  defp build_dispatch_assigns(assigns) do
    state = assigns.state
    config = merge_config(state.opts, assigns.config)

    max_depth =
      Map.get(config, :max_depth) || Map.get(config, "max_depth") ||
        Limits.defaults().max_depth

    max_elements =
      Map.get(config, :max_elements) || Map.get(config, "max_elements") ||
        Limits.defaults().max_elements

    {path, schema} = resolve_path_and_schema(assigns, state)
    instance_path = Path.data_path_to_instance_path(path)
    element_key = JsonFormsLV.Rules.element_key(assigns.uischema, assigns.element_path || [])
    render_key = JsonFormsLV.Rules.render_key(element_key, path)
    raw_input = Map.get(state.raw_inputs || %{}, path, :no_raw)

    value =
      if raw_input_applicable?(raw_input, schema) do
        raw_input
      else
        data_value(state.data, path)
      end

    rule_flags = Map.get(state.rule_state || %{}, render_key, %{visible?: true, enabled?: true})
    visible? = assigns.parent_visible? && Map.get(rule_flags, :visible?, true)
    enabled? = assigns.parent_enabled? && Map.get(rule_flags, :enabled?, true)

    options =
      case assigns.uischema do
        %{"options" => opts} when is_map(opts) -> opts
        _ -> %{}
      end

    uischema_readonly? =
      Map.get(options, "readonly") == true or Map.get(options, "readOnly") == true

    schema_readonly? = is_map(schema) and Map.get(schema, "readOnly") == true
    required? = required?(state.schema, path)

    enabled? =
      if state.readonly or uischema_readonly? or schema_readonly? do
        false
      else
        enabled?
      end

    ctx =
      Map.merge(assigns.context, %{
        root_schema: state.schema,
        schema: schema,
        uischema: assigns.uischema,
        path: path,
        instance_path: instance_path,
        config: config,
        i18n: state.i18n,
        readonly: state.readonly,
        translate:
          Map.get(state.i18n || %{}, :translate) || Map.get(state.i18n || %{}, "translate"),
        element_key: element_key,
        render_key: render_key
      })

    id = dom_id(assigns.form_id, render_key, assigns.uischema)

    element_count =
      if assigns.depth == 0 and is_integer(max_elements) and max_elements > 0 do
        count_elements(assigns.uischema)
      end

    if assigns.depth > max_depth do
      renderer = JsonFormsLV.Phoenix.Renderers.Unknown

      renderer_assigns = assign(assigns, id: id, message: "Max render depth exceeded")

      %{renderer: renderer, renderer_assigns: renderer_assigns}
    else
      if is_integer(element_count) and element_count > max_elements do
        renderer = JsonFormsLV.Phoenix.Renderers.Unknown

        renderer_assigns =
          assign(assigns,
            id: id,
            message: "Max render elements exceeded (#{element_count}/#{max_elements})"
          )

        %{renderer: renderer, renderer_assigns: renderer_assigns}
      else
        kind = Dispatch.kind_for_uischema(assigns.uischema)
        entry = Dispatch.pick_renderer(assigns.uischema, schema, assigns.registry, ctx, kind)
        {renderer, renderer_opts} = entry || {JsonFormsLV.Phoenix.Renderers.Unknown, []}

        errors_for_control = Errors.errors_for_control(state, path)

        show_errors? =
          Errors.show_validator_errors?(state, path) ||
            Errors.has_additional_errors?(errors_for_control)

        renderer_assigns =
          assign(assigns,
            id: id,
            element_key: element_key,
            render_key: render_key,
            path: path,
            instance_path: instance_path,
            schema: schema,
            root_schema: state.schema,
            data: state.data,
            value: value,
            visible?: visible?,
            enabled?: enabled?,
            readonly?: state.readonly,
            required?: required?,
            options: options,
            i18n: state.i18n,
            config: config,
            binding: assigns.binding,
            streams: assigns.streams,
            renderer_opts: renderer_opts,
            ctx: ctx,
            errors_for_control: errors_for_control,
            show_errors?: show_errors?
          )

        %{renderer: renderer, renderer_assigns: renderer_assigns}
      end
    end
  end

  defp resolve_path_and_schema(assigns, %State{} = state) do
    case assigns.uischema do
      %{"type" => "Control", "scope" => scope} when is_binary(scope) ->
        path = Path.schema_pointer_to_data_path(scope)

        schema =
          case Schema.resolve_pointer(state.schema, scope) do
            {:ok, fragment} -> fragment
            {:error, _} -> nil
          end

        {path, schema}

      _ ->
        {assigns.path || "", nil}
    end
  end

  defp data_value(data, path) do
    case Data.get(data, path) do
      {:ok, value} -> value
      {:error, _} -> nil
    end
  end

  defp raw_input_applicable?(:no_raw, _schema), do: false

  defp raw_input_applicable?(_raw_input, %{"type" => type}) when type in ["number", "integer"],
    do: true

  defp raw_input_applicable?(_raw_input, %{"type" => types}) when is_list(types),
    do: "number" in types or "integer" in types

  defp raw_input_applicable?(_raw_input, _schema), do: false

  defp required?(root_schema, path) when is_binary(path) do
    with segments when segments != [] <- Path.parse_data_path(path),
         {leaf, parent_segments} when is_binary(leaf) <- List.pop_at(segments, -1),
         parent_path <- segments_to_path(parent_segments),
         {:ok, parent_schema} <- Schema.resolve_at_data_path(root_schema, parent_path),
         required when is_list(required) <- Map.get(parent_schema, "required") do
      leaf in required
    else
      _ -> false
    end
  end

  defp required?(_root_schema, _path), do: false

  defp segments_to_path([]), do: ""

  defp segments_to_path(segments) do
    segments
    |> Enum.map(&to_string/1)
    |> Enum.join(".")
  end

  defp merge_config(nil, overrides) when is_map(overrides), do: overrides
  defp merge_config(config, nil) when is_map(config), do: config

  defp merge_config(config, overrides) do
    Map.merge(config || %{}, overrides || %{})
  end

  defp dom_id(form_id, render_key, uischema) do
    base =
      case uischema do
        %{"id" => id} when is_binary(id) and id != "" -> id
        %{"type" => type} when is_binary(type) -> type
        _ -> "element"
      end

    hash =
      :crypto.hash(:sha256, form_id <> "|" <> render_key)
      |> Base.url_encode64(padding: false)

    "#{form_id}-#{sanitize_id(base)}-#{hash}"
  end

  defp sanitize_id(value) do
    value
    |> String.replace(".", "-")
    |> String.replace(~r/[^A-Za-z0-9_-]/, "-")
  end

  defp count_elements(%{"elements" => elements}) when is_list(elements) do
    Enum.reduce(elements, 1, fn element, acc ->
      acc + count_elements(element)
    end)
  end

  defp count_elements(_uischema), do: 1
end
