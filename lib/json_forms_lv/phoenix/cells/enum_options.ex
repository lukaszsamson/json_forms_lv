defmodule JsonFormsLV.Phoenix.Cells.EnumOptions do
  @moduledoc """
  Helper for enum option lists.
  """

  alias JsonFormsLV.I18n

  def options(assigns) do
    schema = assigns.schema || %{}

    cond do
      is_list(schema["enum"]) ->
        Enum.map(schema["enum"], fn value ->
          label = default_label(value)
          label = I18n.translate_enum(value, label, assigns.i18n, assigns.ctx)
          %{value: encode_value(value), raw: value, label: label}
        end)

      is_list(schema["oneOf"]) ->
        Enum.map(schema["oneOf"], fn option ->
          value = Map.get(option, "const")
          label = Map.get(option, "title") || default_label(value)
          label = I18n.translate_one_of(option, value, label, assigns.i18n, assigns.ctx)
          %{value: encode_value(value), raw: value, label: label}
        end)

      true ->
        []
    end
  end

  def encode_value(nil), do: ""
  def encode_value(value) when is_binary(value), do: value
  def encode_value(value), do: to_string(value)

  defp default_label(nil), do: ""
  defp default_label(value) when is_binary(value), do: value
  defp default_label(value), do: to_string(value)
end
