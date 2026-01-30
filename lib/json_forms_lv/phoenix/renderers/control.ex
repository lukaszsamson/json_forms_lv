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

    assigns =
      assigns
      |> Map.put(:label, label)
      |> Map.put(:description, description)
      |> Map.put(:input_id, input_id)

    cell_entry =
      Dispatch.pick_renderer(
        assigns.uischema,
        assigns.schema,
        assigns.registry,
        assigns.ctx,
        :cell
      )

    {cell_module, _opts} = cell_entry || {JsonFormsLV.Phoenix.Cells.StringInput, []}

    cell_assigns =
      assigns
      |> Map.take([
        :uischema,
        :schema,
        :root_schema,
        :data,
        :path,
        :instance_path,
        :value,
        :enabled?,
        :readonly?,
        :options,
        :i18n,
        :config,
        :on_change,
        :on_blur,
        :target
      ])
      |> Map.put(:id, input_id)

    assigns =
      assigns
      |> Map.put(:cell_module, cell_module)
      |> Map.put(:cell_assigns, cell_assigns)

    ~H"""
    <%= if @visible? do %>
      <div id={@id} data-jf-control class="jf-control">
        <%= if @label do %>
          <label for={@input_id} class="jf-label">{@label}</label>
        <% end %>
        <%= apply(@cell_module, :render, [@cell_assigns]) %>
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
