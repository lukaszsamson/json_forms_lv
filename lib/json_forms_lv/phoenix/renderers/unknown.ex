defmodule JsonFormsLV.Phoenix.Renderers.Unknown do
  @moduledoc """
  Fallback renderer for unknown UISchema elements.
  """

  use Phoenix.Component

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    message = Map.get(assigns, :message, "Unknown element")

    assigns =
      assigns
      |> Map.put(:message, message)

    ~H"""
    <div id={@id} data-jf-unknown class="jf-unknown">
      {@message}
    </div>
    """
  end
end
