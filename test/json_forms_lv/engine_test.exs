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

  test "touch_all marks submitted and touched" do
    {:ok, state} = Engine.init(%{}, %{}, %{"name" => "Ada"}, %{})

    {:ok, state} = Engine.touch_all(state)

    assert state.submitted == true
    assert MapSet.member?(state.touched, "name")
  end

  test "invalid numeric coercion preserves raw input" do
    schema = %{
      "type" => "object",
      "properties" => %{"age" => %{"type" => "integer"}}
    }

    {:ok, state} = Engine.init(schema, %{}, %{"age" => 1}, %{})

    {:ok, state} = Engine.update_data(state, "age", "abc", %{})

    assert state.data == %{"age" => 1}
    assert state.raw_inputs["age"] == "abc"
  end
end
