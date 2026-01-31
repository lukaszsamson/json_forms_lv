defmodule JsonFormsLV.UISchemaTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.{Engine, UISchema, UISchemaResolver}

  test "default generates controls for object properties" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string"},
        "age" => %{"type" => "number"}
      }
    }

    uischema = UISchema.default(schema)

    assert uischema["type"] == "VerticalLayout"

    scopes = Enum.map(uischema["elements"], & &1["scope"])
    assert scopes == ["#/properties/age", "#/properties/name"]
  end

  test "engine init generates uischema when nil" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string"}
      }
    }

    {:ok, state} = Engine.init(schema, nil, %{"name" => "Ada"}, %{})

    assert state.uischema["type"] == "VerticalLayout"
    assert Enum.at(state.uischema["elements"], 0)["scope"] == "#/properties/name"
  end

  test "resolver expands local $ref" do
    uischema = %{
      "type" => "VerticalLayout",
      "definitions" => %{
        "section" => %{
          "type" => "Group",
          "label" => "Section",
          "elements" => [%{"type" => "Control", "scope" => "#/properties/name"}]
        }
      },
      "elements" => [%{"$ref" => "#/definitions/section"}]
    }

    {:ok, resolved} = UISchemaResolver.resolve(uischema, %{})

    assert Enum.at(resolved["elements"], 0)["type"] == "Group"
  end

  test "resolver rejects remote refs" do
    uischema = %{
      "type" => "VerticalLayout",
      "elements" => [%{"$ref" => "https://example.com/ui"}]
    }

    assert {:error, {:remote_ref, _ref}} = UISchemaResolver.resolve(uischema, %{})
  end
end
