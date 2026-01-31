defmodule JsonFormsLV.EngineTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.Engine

  test "update_data sets data and touched" do
    {:ok, state} = Engine.init(%{}, %{"type" => "Control"}, %{}, %{})

    {:ok, state} = Engine.update_data(state, "profile.name", "Ada", %{touch: true})

    assert state.data == %{"profile" => %{"name" => "Ada"}}
    assert MapSet.member?(state.touched, "profile.name")
  end

  test "update_data handles nested array paths" do
    {:ok, state} = Engine.init(%{}, %{}, %{"items" => [%{"name" => "a"}]}, %{})

    {:ok, state} = Engine.update_data(state, "items.0.name", "b", %{})

    assert state.data == %{"items" => [%{"name" => "b"}]}
  end

  test "update_data returns error for invalid path" do
    {:ok, state} = Engine.init(%{}, %{}, %{}, %{})

    assert {:error, {:invalid_path, "items.5.name"}} =
             Engine.update_data(state, "items.5.name", "x", %{})
  end

  test "validate_on change validates on updates" do
    schema = %{
      "type" => "object",
      "properties" => %{"name" => %{"type" => "string", "minLength" => 1}}
    }

    {:ok, state} = Engine.init(schema, %{}, %{"name" => "Ada"}, %{validate_on: :change})

    {:ok, state} = Engine.update_data(state, "name", "", %{})

    assert Enum.any?(state.errors, &(&1.keyword == "minLength"))
  end

  test "validate_on blur defers change validation" do
    schema = %{
      "type" => "object",
      "properties" => %{"name" => %{"type" => "string", "minLength" => 1}}
    }

    {:ok, state} = Engine.init(schema, %{}, %{"name" => "Ada"}, %{validate_on: :blur})

    {:ok, state} = Engine.update_data(state, "name", "", %{})
    assert state.errors == []

    {:ok, state} = Engine.touch(state, "name")
    assert Enum.any?(state.errors, &(&1.keyword == "minLength"))
  end

  test "validate_on submit defers blur validation" do
    schema = %{
      "type" => "object",
      "properties" => %{"name" => %{"type" => "string", "minLength" => 1}}
    }

    {:ok, state} = Engine.init(schema, %{}, %{"name" => "Ada"}, %{validate_on: :submit})

    {:ok, state} = Engine.update_data(state, "name", "", %{})
    assert state.errors == []

    {:ok, state} = Engine.touch(state, "name")
    assert state.errors == []

    {:ok, state} = Engine.touch_all(state)
    assert Enum.any?(state.errors, &(&1.keyword == "minLength"))
  end

  test "init applies defaults when enabled" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string", "default" => "Ada"},
        "age" => %{"type" => "number"}
      }
    }

    {:ok, state} = Engine.init(schema, %{}, %{}, %{apply_defaults: true})

    assert state.data == %{"name" => "Ada"}

    {:ok, state} = Engine.init(schema, %{}, %{"name" => "Grace"}, %{apply_defaults: true})

    assert state.data == %{"name" => "Grace"}
  end

  test "init applies defaults to array items" do
    schema = %{
      "type" => "array",
      "items" => %{
        "type" => "object",
        "properties" => %{"tag" => %{"type" => "string", "default" => "new"}}
      }
    }

    {:ok, state} = Engine.init(schema, %{}, [%{}], %{apply_defaults: true})

    assert state.data == [%{"tag" => "new"}]
  end

  test "init enforces max_data_bytes" do
    assert {:error, {:max_data_bytes_exceeded, size, 1}} =
             Engine.init(%{}, %{}, %{"name" => "Ada"}, %{max_data_bytes: 1})

    assert size > 1
  end

  test "update_data enforces max_data_bytes" do
    {:ok, state} = Engine.init(%{}, %{}, %{}, %{max_data_bytes: 200})

    big_value = String.duplicate("a", 500)

    assert {:error, {:max_data_bytes_exceeded, _size, 200}} =
             Engine.update_data(state, "payload", big_value, %{})
  end

  test "touch_all marks submitted and touched" do
    {:ok, state} = Engine.init(%{}, %{}, %{"name" => "Ada"}, %{})

    {:ok, state} = Engine.touch_all(state)

    assert state.submitted == true
    assert MapSet.member?(state.touched, "name")
  end

  test "add_item appends to array and creates id" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "items" => %{"type" => "array", "items" => %{"type" => "string"}}
      }
    }

    {:ok, state} = Engine.init(schema, %{}, %{"items" => []}, %{})

    {:ok, state} = Engine.add_item(state, "items", %{})

    assert state.data == %{"items" => [""]}
    assert length(state.array_ids["items"]) == 1
  end

  test "remove_item removes by index" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "items" => %{"type" => "array", "items" => %{"type" => "string"}}
      }
    }

    {:ok, state} = Engine.init(schema, %{}, %{"items" => ["a", "b"]}, %{})

    {:ok, state} = Engine.remove_item(state, "items", "0")

    assert state.data == %{"items" => ["b"]}
    assert length(state.array_ids["items"]) == 1
  end

  test "remove_item removes by stable id" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "items" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{"id" => %{"type" => "string"}}
          }
        }
      }
    }

    data = %{
      "items" => [
        %{"id" => "alpha"},
        %{"id" => "beta"}
      ]
    }

    {:ok, state} = Engine.init(schema, %{}, data, %{})

    {:ok, state} = Engine.remove_item(state, "items", "beta")

    assert state.data == %{"items" => [%{"id" => "alpha"}]}
    assert state.array_ids["items"] == ["alpha"]
  end

  test "move_item reorders items and ids" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "items" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{"id" => %{"type" => "string"}}
          }
        }
      }
    }

    data = %{
      "items" => [
        %{"id" => "first"},
        %{"id" => "second"},
        %{"id" => "third"}
      ]
    }

    {:ok, state} = Engine.init(schema, %{}, data, %{})

    {:ok, state} = Engine.move_item(state, "items", 0, 2)

    assert state.array_ids["items"] == ["second", "third", "first"]
    assert Enum.map(state.data["items"], & &1["id"]) == ["second", "third", "first"]
  end

  test "move_item remaps nested array ids" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "tasks" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "title" => %{"type" => "string"},
              "subtasks" => %{"type" => "array", "items" => %{"type" => "string"}}
            }
          }
        }
      }
    }

    data = %{
      "tasks" => [
        %{"title" => "One", "subtasks" => ["a", "b"]},
        %{"title" => "Two", "subtasks" => ["c"]}
      ]
    }

    {:ok, state} = Engine.init(schema, %{}, data, %{})

    ids_0 = state.array_ids["tasks.0.subtasks"]
    ids_1 = state.array_ids["tasks.1.subtasks"]

    {:ok, state} = Engine.move_item(state, "tasks", 0, 1)

    assert state.array_ids["tasks.0.subtasks"] == ids_1
    assert state.array_ids["tasks.1.subtasks"] == ids_0
  end

  test "remove_item prunes nested array ids" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "tasks" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "title" => %{"type" => "string"},
              "subtasks" => %{"type" => "array", "items" => %{"type" => "string"}}
            }
          }
        }
      }
    }

    data = %{
      "tasks" => [
        %{"title" => "One", "subtasks" => ["a", "b"]},
        %{"title" => "Two", "subtasks" => ["c"]}
      ]
    }

    {:ok, state} = Engine.init(schema, %{}, data, %{})

    ids_1 = state.array_ids["tasks.1.subtasks"]

    {:ok, state} = Engine.remove_item(state, "tasks", 0)

    assert state.array_ids["tasks.0.subtasks"] == ids_1
    refute Map.has_key?(state.array_ids, "tasks.1.subtasks")
  end

  test "invalid numeric coercion preserves raw input" do
    schema = %{
      "type" => "object",
      "properties" => %{"age" => %{"type" => "integer"}}
    }

    {:ok, state} = Engine.init(schema, %{}, %{"age" => 1}, %{})

    {:ok, state} = Engine.update_data(state, "age", "abc", %{})

    assert state.data == %{"age" => nil}
    assert state.raw_inputs["age"] == "abc"
    assert Enum.any?(state.errors, &(&1.keyword == "type"))
  end

  test "empty numeric input clears optional field" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "age" => %{"type" => "integer"}
      }
    }

    {:ok, state} = Engine.init(schema, %{}, %{"age" => 30}, %{})

    {:ok, state} = Engine.update_data(state, "age", "", %{})

    assert state.data == %{}
  end
end
