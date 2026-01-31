defmodule JsonFormsLV.Phoenix.Renderers.Group do
  @moduledoc """
  Renderer for Group UISchema elements.
  """

  use Phoenix.Component

  import JsonFormsLV.Phoenix.Components, only: [dispatch: 1]

  alias JsonFormsLV.I18n

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(%{"type" => "Group"}, _schema, _ctx), do: 10
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    {label, show_label?} = resolve_label(assigns)
    label = I18n.translate_label(label, assigns.i18n, assigns.ctx)
    elements = Map.get(assigns.uischema, "elements", [])

    assigns =
      assigns
      |> assign(:label, label)
      |> assign(:show_label?, show_label?)
      |> assign(:elements, Enum.with_index(elements))

    ~H"""
    <%= if @visible? do %>
      <fieldset id={@id} data-jf-layout="group" class="jf-layout jf-group">
        <%= if @show_label? and @label do %>
          <legend class="jf-group-label">{@label}</legend>
        <% end %>
        <%= for {element, index} <- @elements do %>
          <.dispatch
            state={@state}
            registry={@registry}
            uischema={element}
            data={@data}
            form_id={@form_id}
            binding={@binding}
            streams={@streams}
            path={@path}
            element_path={(@element_path || []) ++ [index]}
            depth={@depth + 1}
            on_change={@on_change}
            on_blur={@on_blur}
            on_submit={@on_submit}
            target={@target}
            config={@config}
            context={@context}
            parent_visible?={@visible?}
            parent_enabled?={@enabled?}
          />
        <% end %>
      </fieldset>
    <% end %>
    """
  end

  defp resolve_label(%{uischema: %{"label" => false}}), do: {nil, false}
  defp resolve_label(%{uischema: %{"label" => %{"show" => false}}}), do: {nil, false}

  defp resolve_label(%{uischema: %{"label" => %{"show" => true, "text" => text}}})
       when is_binary(text),
       do: {text, true}

  defp resolve_label(%{uischema: %{"label" => label}}) when is_binary(label), do: {label, true}
  defp resolve_label(_assigns), do: {nil, true}
end
