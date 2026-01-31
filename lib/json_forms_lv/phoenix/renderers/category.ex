defmodule JsonFormsLV.Phoenix.Renderers.Category do
  @moduledoc """
  Renderer for Category UISchema elements.
  """

  use Phoenix.Component

  import JsonFormsLV.Phoenix.Components, only: [dispatch: 1]

  alias JsonFormsLV.I18n

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(%{"type" => "Category"}, _schema, _ctx), do: 10
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    label = Map.get(assigns.uischema, "label")
    label = I18n.translate_label(label, assigns.i18n, assigns.ctx)
    options = Map.get(assigns.uischema, "options", %{})
    elements = Map.get(assigns.uischema, "elements", [])

    show_label? =
      label && Map.get(assigns.uischema, "label") != false &&
        Map.get(options, "showLabel", true) != false

    show_label? =
      if Map.get(assigns.context || %{}, :categorization_ancestor?) do
        false
      else
        show_label?
      end

    assigns =
      assigns
      |> assign(:label, label)
      |> assign(:show_label?, show_label?)
      |> assign(:elements, Enum.with_index(elements))

    ~H"""
    <%= if @visible? do %>
      <section id={@id} data-jf-layout="category" class="jf-layout jf-category">
        <%= if @show_label? do %>
          <h3 class="jf-category-label">{@label}</h3>
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
      </section>
    <% end %>
    """
  end
end
