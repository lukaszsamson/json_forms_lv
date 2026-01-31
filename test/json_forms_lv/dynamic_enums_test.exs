defmodule JsonFormsLV.DynamicEnumsTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.{DynamicEnums, Engine}

  test "resolves enums from x-url loader" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "status" => %{
          "type" => "string",
          "x-url" => "https://example.com/enums/status"
        }
      }
    }

    loader = fn url, _opts ->
      assert url == "https://example.com/enums/status"
      {:ok, ["open", "closed"]}
    end

    {:ok, resolved} = DynamicEnums.resolve(schema, %{enum_loader: loader})

    assert resolved["properties"]["status"]["enum"] == ["open", "closed"]
  end

  test "resolves enums from x-endpoint with base url" do
    schema = %{
      "$id" => "https://example.com/schema.json",
      "type" => "object",
      "properties" => %{
        "priority" => %{
          "type" => "string",
          "x-endpoint" => "/enums/priorities"
        }
      }
    }

    loader = fn url, _opts ->
      assert url == "https://example.com/enums/priorities"
      {:ok, %{"enum" => ["low", "high"]}}
    end

    {:ok, resolved} = DynamicEnums.resolve(schema, %{enum_loader: loader})

    assert resolved["properties"]["priority"]["enum"] == ["low", "high"]
  end

  test "maps list of const values to oneOf" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "choice" => %{
          "type" => "string",
          "x-url" => "https://example.com/choices"
        }
      }
    }

    loader = fn _url, _opts ->
      {:ok, [%{"const" => "a", "title" => "A"}, %{"const" => "b", "title" => "B"}]}
    end

    {:ok, resolved} = DynamicEnums.resolve(schema, %{enum_loader: loader})

    assert is_list(resolved["properties"]["choice"]["oneOf"])
  end

  test "engine init resolves dynamic enums" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "status" => %{
          "type" => "string",
          "x-url" => "https://example.com/enums/status"
        }
      }
    }

    loader = fn _url, _opts -> {:ok, ["open", "closed"]} end

    {:ok, state} = Engine.init(schema, %{}, %{}, %{enum_loader: loader})

    assert state.schema["properties"]["status"]["enum"] == ["open", "closed"]
  end

  test "resolver reports loading status" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "status" => %{
          "type" => "string",
          "x-url" => "https://example.com/enums/status"
        }
      }
    }

    loader = fn _url, _opts -> {:loading, :pending} end

    {:ok, _resolved, status} = DynamicEnums.resolve_with_status(schema, %{enum_loader: loader})

    assert status["https://example.com/enums/status"] == {:loading, :pending}
  end
end
