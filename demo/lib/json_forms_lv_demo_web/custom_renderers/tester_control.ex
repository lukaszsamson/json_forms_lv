defmodule JsonFormsLvDemoWeb.CustomRenderers.TesterControl do
  @moduledoc """
  Custom control renderer to showcase tester helpers.
  """

  use Phoenix.Component

  alias JsonFormsLV.Phoenix.Renderers.Control
  alias JsonFormsLV.Testers

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(uischema, schema, ctx) do
    predicate =
      Testers.all_of([
        Testers.ui_type_is("Control"),
        Testers.any_of([
          Testers.scope_ends_with("status"),
          Testers.scope_ends_with("priority")
        ]),
        Testers.not_of(Testers.scope_ends_with("ignore"))
      ])

    Testers.rank_with(25, predicate).(uischema, schema, ctx)
  end

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    inner = Control.render(assigns)
    assigns = assign(assigns, inner: inner)

    ~H"""
    <div data-custom-tester="true" class="jf-control jf-tester-highlight">
      {@inner}
    </div>
    """
  end
end
