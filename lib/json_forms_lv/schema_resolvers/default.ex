defmodule JsonFormsLV.SchemaResolvers.Default do
  @moduledoc """
  Default resolver that allows internal refs and rejects remote refs.

  Internal `$ref` expansion is handled by the configured validator during
  compilation.
  """

  @behaviour JsonFormsLV.SchemaResolver

  @impl JsonFormsLV.SchemaResolver
  def resolve(schema, _opts) when is_map(schema) do
    case find_remote_ref(schema) do
      nil -> {:ok, schema}
      ref -> {:error, {:remote_ref, ref}}
    end
  end

  def resolve(_schema, _opts), do: {:error, {:invalid_schema, :expected_map}}

  defp find_remote_ref(map) when is_map(map) do
    Enum.reduce_while(map, nil, fn {key, value}, _acc ->
      cond do
        key == "$ref" and is_binary(value) and String.starts_with?(value, "#") ->
          {:cont, nil}

        key == "$ref" and is_binary(value) ->
          {:halt, value}

        true ->
          case find_remote_ref(value) do
            nil -> {:cont, nil}
            ref -> {:halt, ref}
          end
      end
    end)
  end

  defp find_remote_ref(list) when is_list(list) do
    Enum.reduce_while(list, nil, fn value, _acc ->
      case find_remote_ref(value) do
        nil -> {:cont, nil}
        ref -> {:halt, ref}
      end
    end)
  end

  defp find_remote_ref(_value), do: nil
end
