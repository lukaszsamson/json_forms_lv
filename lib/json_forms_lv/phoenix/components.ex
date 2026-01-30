defmodule JsonFormsLV.Phoenix.Components do
  @moduledoc """
  Phoenix function components for rendering JSON Forms.
  """

  use Phoenix.Component

  alias JsonFormsLV.{Data, Dispatch, Engine, Limits, Path, Registry, Schema, State}

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
  attr(:cells, :list, default: [])
  attr(:opts, :map, default: %{})
  attr(:on_change, :string, default: "jf:change")
  attr(:on_blur, :string, default: "jf:blur")
  attr(:on_submit, :string, default: "jf:submit")

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
          form_id={@id}
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
        form_id={@id}
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
  attr(:form_id, :string, required: true)
  attr(:path, :string, default: "")
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
      |> Map.put(:validation_mode, assigns.validation_mode)
      |> Map.put(:additional_errors, assigns.additional_errors)
      |> Map.put(:readonly, assigns.readonly)
      |> Map.put(:i18n, assigns.i18n)
      |> Map.put(:opts, merge_config(assigns.state.opts, assigns.opts))

    assign(assigns, :state, state)
  end

  defp ensure_state(assigns) do
    state =
      case Engine.init(assigns.schema, assigns.uischema, assigns.data, assigns.opts) do
        {:ok, state} ->
          %State{state | validation_mode: assigns.validation_mode}

        {:error, _reason} ->
          %State{schema: assigns.schema, uischema: assigns.uischema, data: assigns.data}
      end

    state = %State{
      state
      | additional_errors: assigns.additional_errors,
        readonly: assigns.readonly,
        i18n: assigns.i18n
    }

    assign(assigns, :state, state)
  end

  defp ensure_registry(assigns) do
    custom =
      Registry.new(
        control_renderers: assigns.renderers,
        layout_renderers: assigns.renderers,
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
      control_renderers: [JsonFormsLV.Phoenix.Renderers.Control],
      layout_renderers: [
        JsonFormsLV.Phoenix.Renderers.VerticalLayout,
        JsonFormsLV.Phoenix.Renderers.HorizontalLayout
      ],
      cell_renderers: [
        JsonFormsLV.Phoenix.Cells.BooleanInput,
        JsonFormsLV.Phoenix.Cells.NumberInput,
        JsonFormsLV.Phoenix.Cells.StringInput
      ]
    )
  end

  defp build_dispatch_assigns(assigns) do
    state = assigns.state
    config = merge_config(state.opts, assigns.config)
    max_depth = Map.get(config, :max_depth, Limits.defaults().max_depth)

    {path, schema} = resolve_path_and_schema(assigns, state)
    instance_path = Path.data_path_to_instance_path(path)
    value = data_value(state.data, path)
    visible? = assigns.parent_visible?
    enabled? = assigns.parent_enabled? && !state.readonly

    options =
      case assigns.uischema do
        %{"options" => opts} when is_map(opts) -> opts
        _ -> %{}
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
        readonly: state.readonly
      })

    id = dom_id(assigns.form_id, assigns.uischema, path)

    if assigns.depth > max_depth do
      renderer = JsonFormsLV.Phoenix.Renderers.Unknown

      renderer_assigns =
        Map.merge(assigns, %{id: id, message: "Max render depth exceeded"})

      %{renderer: renderer, renderer_assigns: renderer_assigns}
    else
      kind = Dispatch.kind_for_uischema(assigns.uischema)
      entry = Dispatch.pick_renderer(assigns.uischema, schema, assigns.registry, ctx, kind)
      {renderer, renderer_opts} = entry || {JsonFormsLV.Phoenix.Renderers.Unknown, []}

      renderer_assigns =
        Map.merge(assigns, %{
          id: id,
          path: path,
          instance_path: instance_path,
          schema: schema,
          root_schema: state.schema,
          data: state.data,
          value: value,
          visible?: visible?,
          enabled?: enabled?,
          readonly?: state.readonly,
          options: options,
          i18n: state.i18n,
          config: config,
          renderer_opts: renderer_opts,
          ctx: ctx
        })

      %{renderer: renderer, renderer_assigns: renderer_assigns}
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

  defp merge_config(nil, overrides) when is_map(overrides), do: overrides
  defp merge_config(config, nil) when is_map(config), do: config

  defp merge_config(config, overrides) do
    Map.merge(config || %{}, overrides || %{})
  end

  defp dom_id(form_id, uischema, path) do
    base =
      case uischema do
        %{"id" => id} when is_binary(id) and id != "" -> id
        %{"type" => type} when is_binary(type) -> type
        _ -> "element"
      end

    suffix =
      case path do
        "" -> "root"
        _ -> path
      end

    "#{form_id}-#{base}-#{sanitize_id(suffix)}"
  end

  defp sanitize_id(value) do
    value
    |> String.replace(".", "-")
    |> String.replace(~r/[^A-Za-z0-9_-]/, "-")
  end
end
