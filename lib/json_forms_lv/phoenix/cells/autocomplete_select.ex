defmodule JsonFormsLV.Phoenix.Cells.AutocompleteSelect do
  @moduledoc """
  Cell renderer for enum/oneOf autocomplete inputs.
  """

  use Phoenix.Component

  alias JsonFormsLV.Phoenix.Cells.EnumSelect

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(%{"options" => %{"autocomplete" => value}}, %{"enum" => enum}, _ctx)
      when is_list(enum) do
    if autocomplete_enabled?(value), do: 25, else: :not_applicable
  end

  def tester(%{"options" => %{"autocomplete" => value}}, %{"oneOf" => one_of}, _ctx)
      when is_list(one_of) do
    if autocomplete_enabled?(value), do: 24, else: :not_applicable
  end

  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    EnumSelect.render(assigns)
  end

  defp autocomplete_enabled?(true), do: true
  defp autocomplete_enabled?(value) when is_binary(value), do: value != "off"
  defp autocomplete_enabled?(_), do: false
end
