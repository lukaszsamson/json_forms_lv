defmodule JsonFormsLV.TestersTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.Testers

  test "ui_type_is matches exact type" do
    tester = Testers.ui_type_is("Control")

    assert tester.(%{"type" => "Control"}, nil, %{}) == true
    assert tester.(%{"type" => "Group"}, nil, %{}) == false
  end

  test "schema_type_is matches union types" do
    tester = Testers.schema_type_is("string")

    assert tester.(nil, %{"type" => ["string", "null"]}, %{}) == true
    assert tester.(nil, %{"type" => "number"}, %{}) == false
  end

  test "format_is matches schema format" do
    tester = Testers.format_is("date")

    assert tester.(nil, %{"format" => "date"}, %{}) == true
    assert tester.(nil, %{"format" => "date-time"}, %{}) == false
  end

  test "has_option matches flags and values" do
    flag = Testers.has_option("multi")
    value = Testers.has_option("format", "custom")

    assert flag.(%{"options" => %{"multi" => true}}, nil, %{}) == true
    assert flag.(%{"options" => %{"multi" => false}}, nil, %{}) == false
    assert value.(%{"options" => %{"format" => "custom"}}, nil, %{}) == true
    assert value.(%{"options" => %{"format" => "other"}}, nil, %{}) == false
  end

  test "scope_ends_with matches suffix" do
    tester = Testers.scope_ends_with("/name")

    assert tester.(%{"scope" => "#/properties/name"}, nil, %{}) == true
    assert tester.(%{"scope" => "#/properties/title"}, nil, %{}) == false
  end

  test "rank_with returns rank on true" do
    tester = Testers.rank_with(15, fn _uischema, _schema, _ctx -> true end)

    assert tester.(%{}, %{}, %{}) == 15
  end

  test "all_of and any_of combine testers" do
    control = Testers.ui_type_is("Control")
    string = Testers.schema_type_is("string")

    all = Testers.all_of([control, string])
    any = Testers.any_of([control, string])

    assert all.(%{"type" => "Control"}, %{"type" => "string"}, %{}) == true
    assert all.(%{"type" => "Control"}, %{"type" => "number"}, %{}) == false
    assert any.(%{"type" => "Control"}, %{"type" => "number"}, %{}) == true
  end

  test "not_of negates tester" do
    tester = Testers.not_of(Testers.ui_type_is("Control"))

    assert tester.(%{"type" => "Group"}, nil, %{}) == true
    assert tester.(%{"type" => "Control"}, nil, %{}) == false
  end

  test "with_increased_rank adjusts rank" do
    base = fn _uischema, _schema, _ctx -> 10 end
    tester = Testers.with_increased_rank(base, 5)

    assert tester.(%{}, %{}, %{}) == 15
  end

  test "schema_matches applies predicate" do
    tester = Testers.schema_matches(fn schema -> Map.get(schema, "type") == "string" end)

    assert tester.(%{}, %{"type" => "string"}, %{}) == true
    assert tester.(%{}, %{"type" => "number"}, %{}) == false
  end

  test "schema_sub_path_matches resolves pointer" do
    tester =
      Testers.schema_sub_path_matches("#/properties/name", fn schema ->
        Map.get(schema, "type") == "string"
      end)

    schema = %{"properties" => %{"name" => %{"type" => "string"}}}

    assert tester.(%{}, schema, %{}) == true
  end

  test "is_date_control and is_time_control helpers" do
    date = Testers.is_date_control()
    time = Testers.is_time_control()

    assert date.(%{"type" => "Control"}, %{"format" => "date"}, %{}) == true
    assert time.(%{"type" => "Control"}, %{"format" => "time"}, %{}) == true
    assert date.(%{"type" => "Control"}, %{"format" => "date-time"}, %{}) == false
  end

  test "is_range_control helper" do
    tester = Testers.is_range_control()

    assert tester.(%{"options" => %{"slider" => true}}, %{"type" => "number"}, %{}) == true
    assert tester.(%{"options" => %{"slider" => true}}, %{"type" => "string"}, %{}) == false
  end
end
