defmodule JsonFormsLV.Phoenix.Cells.DateTimeInput do
  @moduledoc """
  Cell renderer for date-time inputs.
  """

  use Phoenix.Component

  alias JsonFormsLV.Data

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(_uischema, %{"type" => "string", "format" => "date-time"}, _ctx), do: 15
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    value = assigns |> data_value() |> normalize_datetime()

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
      type="datetime-local"
      value={@value}
      disabled={@disabled?}
      phx-change={@change_event}
      phx-blur={@blur_event}
      phx-target={@target}
    />
    """
  end

  defp normalize_datetime(nil), do: ""

  defp normalize_datetime(%NaiveDateTime{} = value),
    do: value |> NaiveDateTime.to_iso8601() |> trim_datetime()

  defp normalize_datetime(%DateTime{} = value),
    do: value |> DateTime.to_iso8601() |> trim_datetime()

  defp normalize_datetime(value) when is_binary(value) do
    value
    |> String.replace(" ", "T")
    |> trim_datetime()
  end

  defp normalize_datetime(value), do: value |> to_string() |> normalize_datetime()

  defp trim_datetime(value) do
    case Regex.run(~r/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2})/, value) do
      [_, datetime] -> datetime
      _ -> ""
    end
  end

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
