defmodule JsonFormsLV.Phoenix.Renderers.Control do
  @moduledoc """
  Renderer for Control UISchema elements.
  """

  use Phoenix.Component

  alias JsonFormsLV.{Dispatch, I18n}

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(%{"type" => "Control"}, _schema, _ctx), do: 10
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    label = resolve_label(assigns)
    description = resolve_description(assigns)
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
      <div id={@id} data-jf-control class="jf-control">
        <%= if @label do %>
          <label for={@input_id} class="jf-label">{@label}</label>
        <% end %>
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
