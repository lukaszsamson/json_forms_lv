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
    placeholder = placeholder(assigns)
    picker_attrs = picker_attrs(assigns)

    assigns =
      assign(assigns,
        value: value,
        disabled?: disabled?(assigns),
        change_event: change_event,
        blur_event: blur_event,
        placeholder: placeholder,
        picker_attrs: picker_attrs,
        aria_describedby: assigns[:aria_describedby],
        aria_invalid: assigns[:aria_invalid]
      )

    ~H"""
    <input
      {@picker_attrs}
      id={@id}
      name={@path}
      type="date"
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

  defp placeholder(assigns) do
    placeholder = Map.get(assigns.options || %{}, "placeholder")
    if is_binary(placeholder), do: placeholder
  end

  defp picker_attrs(assigns) do
    options = assigns.options || %{}

    %{}
    |> put_attr("data-jf-date-format", Map.get(options, "dateFormat"))
    |> put_attr("data-jf-date-save-format", Map.get(options, "dateSaveFormat"))
    |> put_attr("data-jf-views", Map.get(options, "views"))
    |> put_attr("data-jf-clear-label", Map.get(options, "clearLabel"))
    |> put_attr("data-jf-cancel-label", Map.get(options, "cancelLabel"))
    |> put_attr("data-jf-ok-label", Map.get(options, "okLabel"))
  end

  defp put_attr(attrs, _key, nil), do: attrs

  defp put_attr(attrs, key, value) when is_binary(value) do
    Map.put(attrs, key, value)
  end

  defp put_attr(attrs, key, value) when is_boolean(value) do
    Map.put(attrs, key, to_string(value))
  end

  defp put_attr(attrs, key, value) when is_integer(value) do
    Map.put(attrs, key, Integer.to_string(value))
  end

  defp put_attr(attrs, key, value) when is_list(value) do
    value =
      value
      |> Enum.map(&to_string/1)
      |> Enum.join(",")

    Map.put(attrs, key, value)
  end

  defp put_attr(attrs, _key, _value), do: attrs
end
