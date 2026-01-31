defmodule JsonFormsLvDemoWeb.CustomRenderers.SpotlightGroup do
  @moduledoc """
  Custom layout renderer for spotlight groups.
  """

  use Phoenix.Component

  import JsonFormsLV.Phoenix.Components, only: [dispatch: 1]

  alias JsonFormsLV.I18n

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(%{"type" => "Group", "options" => %{"variant" => "spotlight"}}, _schema, _ctx),
    do: 30

  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    label = Map.get(assigns.uischema, "label")
    label = I18n.translate_label(label, assigns.i18n, assigns.ctx)
    elements = Map.get(assigns.uischema, "elements", [])

    assigns =
      assigns
      |> assign(:label, label)
      |> assign(:elements, Enum.with_index(elements))

    ~H"""
    <%= if @visible? do %>
      <fieldset
        id={@id}
        data-jf-layout="group"
        data-custom-layout="spotlight"
        class="jf-layout jf-group jf-group-spotlight"
      >
        <%= if @label do %>
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
end
