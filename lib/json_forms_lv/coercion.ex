defmodule JsonFormsLV.Coercion do
  @moduledoc """
  Coerce raw input values based on a schema fragment.
  """

  @spec coerce_with_raw(term(), map() | nil, map() | keyword()) ::
          {:ok, term()} | {:error, term()}
  def coerce_with_raw(value, schema, opts \\ %{}) do
    case schema_type(schema) do
      "boolean" -> {:ok, coerce_boolean(value)}
      "integer" -> coerce_integer_with_raw(value)
      "number" -> coerce_number_with_raw(value)
      "array" -> coerce_array_with_raw(value, schema, opts)
      "string" -> {:ok, coerce_string(value)}
      types when is_list(types) -> coerce_union_with_raw(value, types, opts)
      _ -> {:ok, value}
    end
  end

  @spec coerce(term(), map() | nil, map() | keyword()) :: term()
  def coerce(value, schema, opts \\ %{}) do
    case coerce_with_raw(value, schema, opts) do
      {:ok, coerced} -> coerced
      {:error, raw} -> raw
    end
  end

  defp schema_type(%{"type" => type}) when is_binary(type), do: type
  defp schema_type(%{"type" => type}) when is_list(type), do: type
  defp schema_type(_), do: nil

  defp coerce_boolean(value) when value in [true, "true", "on"], do: true
  defp coerce_boolean(value) when value in [false, "false", nil, ""], do: false
  defp coerce_boolean(value), do: value

  defp coerce_string(value) when is_binary(value), do: value
  defp coerce_string(nil), do: nil
  defp coerce_string(value), do: to_string(value)

  defp coerce_integer_with_raw(value) when is_integer(value), do: {:ok, value}
  defp coerce_integer_with_raw(""), do: {:ok, nil}

  defp coerce_integer_with_raw(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, value}
    end
  end

  defp coerce_integer_with_raw(value), do: {:ok, value}

  defp coerce_number_with_raw(value) when is_number(value), do: {:ok, value}
  defp coerce_number_with_raw(""), do: {:ok, nil}

  defp coerce_number_with_raw(value) when is_binary(value) do
    case Float.parse(value) do
      {num, ""} -> {:ok, num}
      _ -> {:error, value}
    end
  end

  defp coerce_number_with_raw(value), do: {:ok, value}

  defp coerce_array_with_raw(value, schema, opts) when is_list(value) do
    items_schema = Map.get(schema || %{}, "items")

    coerced =
      Enum.map(value, fn entry ->
        coerce(entry, items_schema, opts)
      end)

    {:ok, coerced}
  end

  defp coerce_array_with_raw("", _schema, _opts), do: {:ok, []}
  defp coerce_array_with_raw(nil, _schema, _opts), do: {:ok, nil}
  defp coerce_array_with_raw(value, _schema, _opts), do: {:ok, value}

  defp coerce_union_with_raw(value, types, opts) do
    empty_string_as_null? = empty_string_as_null?(opts)

    if "null" in types and empty_string_as_null? and value == "" do
      {:ok, nil}
    else
      non_null_type = Enum.find(types, &(&1 != "null"))

      case coerce_with_raw(value, %{"type" => non_null_type}, opts) do
        {:ok, coerced} -> {:ok, coerced}
        {:error, raw} -> {:error, raw}
      end
    end
  end

  defp empty_string_as_null?(opts) when is_map(opts) do
    Map.get(opts, :empty_string_as_null, true)
  end

  defp empty_string_as_null?(opts) when is_list(opts) do
    Keyword.get(opts, :empty_string_as_null, true)
  end
end
