defmodule JsonFormsLV.Phoenix.Renderers.Label do
  @moduledoc """
  Renderer for Label UISchema elements.
  """

  use Phoenix.Component

  alias JsonFormsLV.I18n

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(%{"type" => "Label"}, _schema, _ctx), do: 10
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    text = Map.get(assigns.uischema, "text")
    text = I18n.translate_label_text(text, assigns.i18n, assigns.ctx)
    assigns = assign(assigns, :text, text)

    ~H"""
    <%= if @visible? and @text do %>
      <div id={@id} data-jf-label class="jf-label-element">
        {@text}
      </div>
    <% end %>
    """
  end
end
