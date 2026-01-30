defmodule JsonFormsLV.DataTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.Data

  test "get reads nested maps and arrays" do
    data = %{"address" => %{"street" => "Main"}, "items" => [%{"name" => "A"}]}

    assert {:ok, "Main"} = Data.get(data, "address.street")
    assert {:ok, "A"} = Data.get(data, "items.0.name")
  end

  test "put creates nested map paths" do
    data = %{}

    assert {:ok, updated} = Data.put(data, "profile.name", "Ada")
    assert updated == %{"profile" => %{"name" => "Ada"}}
  end

  test "put updates list items" do
    data = %{"items" => [%{"name" => "A"}]}

    assert {:ok, updated} = Data.put(data, "items.0.name", "B")
    assert updated == %{"items" => [%{"name" => "B"}]}
  end

  test "put rejects out-of-range list indices" do
    data = %{"items" => [%{"name" => "A"}]}

    assert {:error, {:invalid_path, "items.1"}} = Data.put(data, "items.1", "B")
  end

  test "update applies a function" do
    data = %{"count" => 1}

    assert {:ok, updated} = Data.update(data, "count", &(&1 + 1))
    assert updated == %{"count" => 2}
  end
end
