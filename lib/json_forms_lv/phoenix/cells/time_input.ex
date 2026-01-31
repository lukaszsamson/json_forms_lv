defmodule JsonFormsLV.Phoenix.Cells.TimeInput do
  @moduledoc """
  Cell renderer for time inputs.
  """

  use Phoenix.Component

  alias JsonFormsLV.Data

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(_uischema, %{"type" => "string", "format" => "time"}, _ctx), do: 15
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    value = assigns |> data_value() |> normalize_time()

    change_event = if assigns.binding == :per_input, do: assigns.on_change
    blur_event = assigns.on_blur
    placeholder = placeholder(assigns)

    assigns =
      assign(assigns,
        value: value,
        disabled?: disabled?(assigns),
        change_event: change_event,
        blur_event: blur_event,
        placeholder: placeholder,
        aria_describedby: assigns[:aria_describedby],
        aria_invalid: assigns[:aria_invalid]
      )

    ~H"""
    <input
      id={@id}
      name={@path}
      type="time"
      value={@value}
      placeholder={@placeholder}
      disabled={@disabled?}
      aria-describedby={@aria_describedby}
      aria-invalid={@aria_invalid}
      phx-change={@change_event}
      phx-blur={@blur_event}
      phx-target={@target}
    />
    """
  end

  defp normalize_time(nil), do: ""

  defp normalize_time(%Time{} = value),
    do: value |> Time.to_iso8601() |> trim_time()

  defp normalize_time(%NaiveDateTime{} = value),
    do: value |> NaiveDateTime.to_time() |> Time.to_iso8601() |> trim_time()

  defp normalize_time(%DateTime{} = value),
    do: value |> DateTime.to_time() |> Time.to_iso8601() |> trim_time()

  defp normalize_time(value) when is_binary(value),
    do: value |> String.replace(" ", "T") |> trim_time()

  defp normalize_time(value), do: value |> to_string() |> normalize_time()

  defp trim_time(value) do
    case Regex.run(~r/^(\d{2}:\d{2})/, value) do
      [_, time] -> time
      _ -> ""
    end
  end

  defp data_value(assigns) do
    case Data.get(assigns.data, assigns.path) do
      {:ok, value} -> value
      {:error, _} -> assigns.value
    end
  end

  defp placeholder(assigns) do
    placeholder = Map.get(assigns.options || %{}, "placeholder")
    if is_binary(placeholder), do: placeholder
  end

  defp disabled?(assigns) do
    not assigns.enabled? or assigns.readonly?
  end
end
