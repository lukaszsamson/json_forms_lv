defmodule JsonFormsLV.RulesTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

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

  test "show rule toggles visibility" do
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
        "effect" => "SHOW",
        "condition" => %{
          "scope" => "#/properties/flag",
          "schema" => %{"const" => true}
        }
      }
    }

    element_key = Rules.element_key(uischema, [])
    render_key = Rules.render_key(element_key, "name")

    {:ok, state} = Engine.init(schema, uischema, %{"flag" => true, "name" => "Ada"}, %{})
    assert state.rule_state[render_key][:visible?] == true

    {:ok, state} = Engine.init(schema, uischema, %{"flag" => false, "name" => "Ada"}, %{})
    assert state.rule_state[render_key][:visible?] == false
  end

  test "enable rule toggles enabled state" do
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
        "effect" => "ENABLE",
        "condition" => %{
          "scope" => "#/properties/flag",
          "schema" => %{"const" => true}
        }
      }
    }

    element_key = Rules.element_key(uischema, [])
    render_key = Rules.render_key(element_key, "name")

    {:ok, state} = Engine.init(schema, uischema, %{"flag" => true, "name" => "Ada"}, %{})
    assert state.rule_state[render_key][:enabled?] == true

    {:ok, state} = Engine.init(schema, uischema, %{"flag" => false, "name" => "Ada"}, %{})
    assert state.rule_state[render_key][:enabled?] == false
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

  test "composed condition logs warning and is treated as false" do
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
          "type" => "AND",
          "conditions" => [
            %{"scope" => "#/properties/flag", "schema" => %{"const" => true}}
          ]
        }
      }
    }

    element_key = Rules.element_key(uischema, [])
    render_key = Rules.render_key(element_key, "name")

    log =
      capture_log(fn ->
        {:ok, state} = Engine.init(schema, uischema, %{"flag" => true, "name" => "Ada"}, %{})
        assert state.rule_state[render_key][:visible?] == true
      end)

    assert log =~ "Unsupported composed rule condition"
  end
end
