defmodule JsonFormsLV.Coercion do
  @moduledoc """
  Coerce raw input values based on a schema fragment.
  """

  @spec coerce(term(), map() | nil, map() | keyword()) :: term()
  def coerce(value, schema, opts \\ %{}) do
    case schema_type(schema) do
      "boolean" -> coerce_boolean(value)
      "integer" -> coerce_integer(value)
      "number" -> coerce_number(value)
      "string" -> coerce_string(value)
      types when is_list(types) -> coerce_union(value, types, opts)
      _ -> value
    end
  end

  defp schema_type(%{"type" => type}) when is_binary(type), do: type
  defp schema_type(%{"type" => type}) when is_list(type), do: type
  defp schema_type(_), do: nil

  defp coerce_boolean(value) when value in [true, "true", "on"], do: true
  defp coerce_boolean(value) when value in [false, "false", nil, ""], do: false
  defp coerce_boolean(value), do: value

  defp coerce_integer(value) when is_integer(value), do: value
  defp coerce_integer(""), do: nil

  defp coerce_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end

  defp coerce_integer(value), do: value

  defp coerce_number(value) when is_number(value), do: value
  defp coerce_number(""), do: nil

  defp coerce_number(value) when is_binary(value) do
    case Float.parse(value) do
      {num, ""} -> num
      _ -> value
    end
  end

  defp coerce_number(value), do: value

  defp coerce_string(value) when is_binary(value), do: value
  defp coerce_string(nil), do: nil
  defp coerce_string(value), do: to_string(value)

  defp coerce_union(value, types, opts) do
    empty_string_as_null? = empty_string_as_null?(opts)

    if "null" in types and empty_string_as_null? and value == "" do
      nil
    else
      non_null_type = Enum.find(types, &(&1 != "null"))
      coerce(value, %{"type" => non_null_type}, opts)
    end
  end

  defp empty_string_as_null?(opts) when is_map(opts) do
    Map.get(opts, :empty_string_as_null, true)
  end

  defp empty_string_as_null?(opts) when is_list(opts) do
    Keyword.get(opts, :empty_string_as_null, true)
  end
end
