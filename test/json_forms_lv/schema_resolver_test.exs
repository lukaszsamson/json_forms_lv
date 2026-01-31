defmodule JsonFormsLV.SchemaResolverTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.Engine

  test "default resolver rejects remote refs" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "name" => %{"$ref" => "https://example.com/schema"}
      }
    }

    assert {:error, {:remote_ref, _ref}} = Engine.init(schema, %{}, %{}, %{})
  end

  test "custom schema resolver is used in init" do
    schema = %{
      "type" => "object",
      "properties" => %{"name" => %{"type" => "string"}}
    }

    {:ok, state} =
      Engine.init(schema, %{}, %{}, %{schema_resolver: JsonFormsLV.CustomSchemaResolverTest})

    assert state.schema["resolved"] == true
  end
end
