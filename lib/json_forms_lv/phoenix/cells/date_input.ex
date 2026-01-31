defmodule JsonFormsLV.Phoenix.Cells.DateInput do
  @moduledoc """
  Cell renderer for date inputs.
  """

  use Phoenix.Component

  alias JsonFormsLV.Data

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(_uischema, %{"type" => "string", "format" => "date"}, _ctx), do: 16
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    value = assigns |> data_value() |> normalize_date()

    change_event = if assigns.binding == :per_input, do: assigns.on_change
    blur_event = assigns.on_blur

    assigns =
      assign(assigns,
        value: value,
        disabled?: disabled?(assigns),
        change_event: change_event,
        blur_event: blur_event
      )

    ~H"""
    <input
      id={@id}
      name={@path}
      type="date"
      value={@value}
      disabled={@disabled?}
      phx-change={@change_event}
      phx-blur={@blur_event}
      phx-target={@target}
    />
    """
  end

  defp normalize_date(nil), do: ""
  defp normalize_date(%Date{} = value), do: Date.to_iso8601(value)

  defp normalize_date(%NaiveDateTime{} = value),
    do: value |> NaiveDateTime.to_date() |> Date.to_iso8601()

  defp normalize_date(%DateTime{} = value), do: value |> DateTime.to_date() |> Date.to_iso8601()

  defp normalize_date(value) when is_binary(value) do
    case Regex.run(~r/^(\d{4}-\d{2}-\d{2})/, value) do
      [_, date] -> date
      _ -> ""
    end
  end

  defp normalize_date(value), do: value |> to_string() |> normalize_date()

  defp data_value(assigns) do
    case Data.get(assigns.data, assigns.path) do
      {:ok, value} -> value
      {:error, _} -> assigns.value
    end
  end

  defp disabled?(assigns) do
    not assigns.enabled? or assigns.readonly?
  end
end
