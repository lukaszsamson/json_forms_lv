defmodule JsonFormsLV.PathTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.Path

  test "schema_pointer_to_data_path ignores schema navigation segments" do
    assert Path.schema_pointer_to_data_path("#/properties/foo/properties/bar") == "foo.bar"

    assert Path.schema_pointer_to_data_path("#/properties/pair/items/0/properties/left") ==
             "pair.0.left"

    assert Path.schema_pointer_to_data_path("#") == ""
  end

  test "schema_pointer_to_data_path decodes pointer escapes" do
    assert Path.schema_pointer_to_data_path("#/properties/a~1b/properties/c~0d") ==
             "a/b.c~d"
  end

  test "data path and instance path conversions" do
    assert Path.data_path_to_instance_path("foo.bar.0") == "/foo/bar/0"
    assert Path.instance_path_to_data_path("/foo/bar/0") == "foo.bar.0"
    assert Path.data_path_to_instance_path("") == ""
    assert Path.instance_path_to_data_path("") == ""
  end

  test "parse and join data paths" do
    assert Path.parse_data_path("foo.bar.0") == ["foo", "bar", 0]
    assert Path.parse_data_path("") == []
    assert Path.join("foo.bar", "baz") == "foo.bar.baz"
    assert Path.join("", "baz") == "baz"
    assert Path.join("foo", "") == "foo"
  end
end
