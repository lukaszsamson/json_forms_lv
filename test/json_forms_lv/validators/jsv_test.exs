defmodule JsonFormsLV.Validators.JSVTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.Validators.JSV

  test "validate returns normalized errors" do
    schema = %{
      "type" => "object",
      "properties" => %{"age" => %{"type" => "integer"}}
    }

    {:ok, compiled} = JSV.compile(schema, [])
    errors = JSV.validate(compiled, %{"age" => "nope"}, [])

    assert is_list(errors)
    assert length(errors) > 0
    assert Enum.all?(errors, &match?(%JsonFormsLV.Error{}, &1))
  end
end
