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
    {text, show_label?} = resolve_label(assigns.uischema)
    text = I18n.translate_label_text(text, assigns.i18n, assigns.ctx)
    assigns = assign(assigns, text: text, show_label?: show_label?)

    ~H"""
    <%= if @visible? and @show_label? and @text do %>
      <div id={@id} data-jf-label class="jf-label-element">
        {@text}
      </div>
    <% end %>
    """
  end

  defp resolve_label(%{"text" => text, "label" => %{"show" => false}}), do: {text, false}
  defp resolve_label(%{"label" => false}), do: {nil, false}
  defp resolve_label(%{"label" => %{"show" => false}}), do: {nil, false}

  defp resolve_label(%{"label" => %{"show" => true, "text" => text}}) when is_binary(text),
    do: {text, true}

  defp resolve_label(%{"text" => text}) when is_binary(text), do: {text, true}
  defp resolve_label(_), do: {nil, true}
end
