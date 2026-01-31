defmodule JsonFormsLV.SchemaTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.Schema
  alias JsonFormsLV.Validators.JSV

  test "resolve_pointer walks a JSON pointer" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "address" => %{
          "type" => "object",
          "properties" => %{"street" => %{"type" => "string"}}
        }
      }
    }

    assert {:ok, %{"type" => "string"}} =
             Schema.resolve_pointer(schema, "#/properties/address/properties/street")

    assert {:ok, ^schema} = Schema.resolve_pointer(schema, "#")
    assert {:error, _} = Schema.resolve_pointer(schema, "#/properties/missing")
  end

  test "resolve_at_data_path handles objects and arrays" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "items" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{"name" => %{"type" => "string"}}
          }
        },
        "pair" => %{
          "type" => "array",
          "items" => [
            %{"type" => "object", "properties" => %{"left" => %{"type" => "string"}}},
            %{"type" => "number"}
          ]
        }
      }
    }

    assert {:ok, %{"type" => "string"}} = Schema.resolve_at_data_path(schema, "items.0.name")
    assert {:ok, %{"type" => "string"}} = Schema.resolve_at_data_path(schema, "pair.0.left")
    assert {:ok, %{"type" => "object"}} = Schema.resolve_at_data_path(schema, "items.2")
  end

  test "resolve_at_data_path applies conditional branches" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "mode" => %{"type" => "string"},
        "detail" => %{"type" => "string"}
      },
      "if" => %{"properties" => %{"mode" => %{"const" => "advanced"}}},
      "then" => %{"required" => ["detail"]},
      "else" => %{"required" => ["mode"]}
    }

    validator = %{module: JSV, compiled: nil}

    {:ok, advanced} =
      Schema.resolve_at_data_path(schema, "", %{"mode" => "advanced"}, validator, [])

    {:ok, basic} =
      Schema.resolve_at_data_path(schema, "", %{"mode" => "basic"}, validator, [])

    assert "detail" in (advanced["required"] || [])
    refute "mode" in (advanced["required"] || [])
    assert "mode" in (basic["required"] || [])
  end
end
