defmodule JsonFormsLvDemoWeb.CustomCells.ShoutInput do
  @moduledoc """
  Custom string cell for the demo.
  """

  use Phoenix.Component

  alias JsonFormsLV.Testers

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(uischema, schema, ctx) do
    Testers.rank_with(
      30,
      Testers.all_of([
        Testers.schema_type_is("string"),
        Testers.has_option("format", "shout")
      ])
    ).(uischema, schema, ctx)
  end

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    change_event = if assigns.binding == :per_input, do: assigns.on_change
    value = assigns.value || ""

    assigns =
      assign(assigns,
        value: value,
        change_event: change_event,
        disabled?: disabled?(assigns),
        preview: String.upcase(value),
        aria_describedby: assigns[:aria_describedby],
        aria_invalid: assigns[:aria_invalid]
      )

    ~H"""
    <div class="jf-custom-shout">
      <input
        id={@id}
        name={@path}
        type="text"
        value={@value}
        data-custom-cell="shout"
        disabled={@disabled?}
        aria-describedby={@aria_describedby}
        aria-invalid={@aria_invalid}
        phx-change={@change_event}
        phx-blur={@on_blur}
        phx-target={@target}
      />
      <p class="jf-custom-preview">Preview: {@preview}</p>
    </div>
    """
  end

  defp disabled?(assigns) do
    not assigns.enabled? or assigns.readonly?
  end
end
