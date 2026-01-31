defmodule JsonFormsLV.CustomSchemaResolverTest do
  @behaviour JsonFormsLV.SchemaResolver

  @impl JsonFormsLV.SchemaResolver
  def resolve(schema, _opts) when is_map(schema) do
    {:ok, Map.put(schema, "resolved", true)}
  end

  def resolve(_schema, _opts), do: {:error, {:invalid_schema, :expected_map}}
end
