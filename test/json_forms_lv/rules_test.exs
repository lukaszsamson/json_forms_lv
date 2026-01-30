defmodule JsonFormsLV.RulesTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.{Engine, Rules}

  test "hide rule toggles visibility" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "flag" => %{"type" => "boolean"},
        "name" => %{"type" => "string"}
      }
    }

    uischema = %{
      "type" => "Control",
      "scope" => "#/properties/name",
      "rule" => %{
        "effect" => "HIDE",
        "condition" => %{
          "scope" => "#/properties/flag",
          "schema" => %{"const" => true}
        }
      }
    }

    {:ok, state} = Engine.init(schema, uischema, %{"flag" => true, "name" => "Ada"}, %{})

    element_key = Rules.element_key(uischema, [])
    render_key = Rules.render_key(element_key, "name")

    assert state.rule_state[render_key][:visible?] == false
  end

  test "failWhenUndefined flips condition to false" do
    schema = %{
      "type" => "object",
      "properties" => %{"name" => %{"type" => "string"}}
    }

    uischema = %{
      "type" => "Control",
      "scope" => "#/properties/name",
      "rule" => %{
        "effect" => "DISABLE",
        "failWhenUndefined" => true,
        "condition" => %{
          "scope" => "#/properties/missing",
          "schema" => %{"const" => true}
        }
      }
    }

    {:ok, state} = Engine.init(schema, uischema, %{"name" => "Ada"}, %{})

    element_key = Rules.element_key(uischema, [])
    render_key = Rules.render_key(element_key, "name")

    assert state.rule_state[render_key][:enabled?] == true
  end
end
