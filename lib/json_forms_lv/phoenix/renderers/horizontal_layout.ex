defmodule JsonFormsLV.Phoenix.Renderers.HorizontalLayout do
  @moduledoc """
  Renderer for HorizontalLayout UISchema elements.
  """

  use Phoenix.Component

  import JsonFormsLV.Phoenix.Components, only: [dispatch: 1]

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(%{"type" => "HorizontalLayout"}, _schema, _ctx), do: 10
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    elements = Map.get(assigns.uischema, "elements", [])
    assigns = Map.put(assigns, :elements, elements)

    ~H"""
    <%= if @visible? do %>
      <div id={@id} data-jf-layout="horizontal" class="jf-layout jf-horizontal">
        <%= for element <- @elements do %>
          <.dispatch
            state={@state}
            registry={@registry}
            uischema={element}
            form_id={@form_id}
            path={@path}
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
