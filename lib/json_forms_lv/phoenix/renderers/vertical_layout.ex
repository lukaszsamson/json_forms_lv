defmodule JsonFormsLV.Phoenix.Renderers.VerticalLayout do
  @moduledoc """
  Renderer for VerticalLayout UISchema elements.
  """

  use Phoenix.Component

  import JsonFormsLV.Phoenix.Components, only: [dispatch: 1]

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(%{"type" => "VerticalLayout"}, _schema, _ctx), do: 10
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    elements = Map.get(assigns.uischema, "elements", [])
    assigns = assign(assigns, :elements, Enum.with_index(elements))

    ~H"""
    <%= if @visible? do %>
      <div id={@id} data-jf-layout="vertical" class="jf-layout jf-vertical">
        <%= for {element, index} <- @elements do %>
          <.dispatch
            state={@state}
            registry={@registry}
            uischema={element}
            form_id={@form_id}
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
      </div>
    <% end %>
    """
  end
end
