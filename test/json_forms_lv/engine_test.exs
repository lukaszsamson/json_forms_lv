defmodule JsonFormsLV.EngineTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.Engine

  test "update_data sets data and touched" do
    {:ok, state} = Engine.init(%{}, %{"type" => "Control"}, %{}, %{})

    {:ok, state} = Engine.update_data(state, "profile.name", "Ada", %{touch: true})

    assert state.data == %{"profile" => %{"name" => "Ada"}}
    assert MapSet.member?(state.touched, "profile.name")
  end
end
