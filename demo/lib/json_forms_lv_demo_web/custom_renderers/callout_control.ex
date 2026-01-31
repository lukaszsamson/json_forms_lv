defmodule JsonFormsLvDemoWeb.CustomRenderers.CalloutControl do
  @moduledoc """
  Custom control renderer for demo callouts.
  """

  use Phoenix.Component

  alias JsonFormsLV.{Dispatch, I18n, Testers}

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(uischema, schema, ctx) do
    Testers.rank_with(
      25,
      Testers.all_of([
        Testers.ui_type_is("Control"),
        Testers.has_option("format", "callout")
      ])
    ).(uischema, schema, ctx)
  end

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    label = resolve_label(assigns)
    description = resolve_description(assigns)
    label = I18n.translate_label(label, assigns.i18n, assigns.ctx)
    description = I18n.translate_description(description, assigns.i18n, assigns.ctx)
    input_id = "#{assigns.id}-input"

    assigns = assign(assigns, label: label, description: description, input_id: input_id)

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
      <section id={@id} data-custom-control="callout" class="jf-control jf-control-callout">
        <header class="jf-callout-header">
          <%= if @label do %>
            <label for={@input_id} class="jf-callout-title">{@label}</label>
          <% end %>
        </header>
        <div class="jf-callout-body">
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
          />
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
      </section>
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

  defp dynamic_component(assigns) do
    {mod, assigns} = Map.pop(assigns, :module)
    {func, assigns} = Map.pop(assigns, :function)
    apply(mod, func, [assigns])
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
end
