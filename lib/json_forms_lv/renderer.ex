defmodule JsonFormsLV.Renderer do
  @moduledoc """
  Behaviour for JSON Forms renderers.
  """

  @callback tester(uischema :: map(), schema_fragment :: map() | nil, ctx :: map()) ::
              non_neg_integer() | :not_applicable

  @callback render(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
end
