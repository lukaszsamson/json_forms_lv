defmodule JsonFormsLV.Phoenix.Cells.NumberInput do
  @moduledoc """
  Cell renderer for number and integer inputs.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(_uischema, %{"type" => "integer"}, _ctx), do: 10
  def tester(_uischema, %{"type" => "number"}, _ctx), do: 9
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    inputmode = inputmode(assigns.schema)

    value =
      case assigns.value do
        nil -> ""
        _ -> to_string(assigns.value)
      end

    assigns =
      assigns
      |> Map.put(:inputmode, inputmode)
      |> Map.put(:value, value)
      |> Map.put(:disabled?, disabled?(assigns))

    ~H"""
    <input
      id={@id}
      name={@path}
      type="text"
      inputmode={@inputmode}
      value={@value}
      disabled={@disabled?}
      phx-change={JS.push(@on_change, value: %{path: @path}, target: @target)}
      phx-blur={JS.push(@on_blur, value: %{path: @path, meta: %{touch: true}}, target: @target)}
    />
    """
  end

  defp inputmode(%{"type" => "integer"}), do: "numeric"
  defp inputmode(%{"type" => "number"}), do: "decimal"
  defp inputmode(_), do: "numeric"

  defp disabled?(assigns) do
    not assigns.enabled? or assigns.readonly?
  end
end
