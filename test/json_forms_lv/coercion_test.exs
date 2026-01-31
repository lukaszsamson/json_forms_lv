defmodule JsonFormsLV.CoercionTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.Coercion

  test "coerces integers" do
    assert Coercion.coerce_with_raw("10", %{"type" => "integer"}) == {:ok, 10}
    assert Coercion.coerce_with_raw("10.5", %{"type" => "integer"}) == {:error, "10.5"}
  end

  test "coerces numbers" do
    assert Coercion.coerce_with_raw("10.5", %{"type" => "number"}) == {:ok, 10.5}
  end

  test "coerces booleans" do
    assert Coercion.coerce_with_raw("on", %{"type" => "boolean"}) == {:ok, true}
    assert Coercion.coerce_with_raw("false", %{"type" => "boolean"}) == {:ok, false}
  end

  test "coerces arrays using items schema" do
    schema = %{"type" => "array", "items" => %{"type" => "integer"}}

    assert Coercion.coerce_with_raw(["1", "2"], schema) == {:ok, [1, 2]}
  end

  test "union types respect empty_string_as_null flag" do
    schema = %{"type" => ["null", "string"]}

    assert Coercion.coerce_with_raw("", schema, %{empty_string_as_null: true}) == {:ok, nil}
    assert Coercion.coerce_with_raw("", schema, %{empty_string_as_null: false}) == {:ok, ""}
  end
end
