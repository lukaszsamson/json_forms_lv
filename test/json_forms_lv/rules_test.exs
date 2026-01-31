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

  test "composed AND condition evaluates all subconditions" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "flag" => %{"type" => "boolean"},
        "enabled" => %{"type" => "boolean"},
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
            %{"scope" => "#/properties/flag", "schema" => %{"const" => true}},
            %{"scope" => "#/properties/enabled", "schema" => %{"const" => true}}
          ]
        }
      }
    }

    element_key = Rules.element_key(uischema, [])
    render_key = Rules.render_key(element_key, "name")

    {:ok, state} =
      Engine.init(schema, uischema, %{"flag" => true, "enabled" => true, "name" => "Ada"}, %{})

    assert state.rule_state[render_key][:visible?] == false

    {:ok, state} =
      Engine.init(schema, uischema, %{"flag" => true, "enabled" => false, "name" => "Ada"}, %{})

    assert state.rule_state[render_key][:visible?] == true
  end

  test "composed OR condition evaluates any subcondition" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "flag" => %{"type" => "boolean"},
        "enabled" => %{"type" => "boolean"},
        "name" => %{"type" => "string"}
      }
    }

    uischema = %{
      "type" => "Control",
      "scope" => "#/properties/name",
      "rule" => %{
        "effect" => "HIDE",
        "condition" => %{
          "type" => "OR",
          "conditions" => [
            %{"scope" => "#/properties/flag", "schema" => %{"const" => true}},
            %{"scope" => "#/properties/enabled", "schema" => %{"const" => true}}
          ]
        }
      }
    }

    element_key = Rules.element_key(uischema, [])
    render_key = Rules.render_key(element_key, "name")

    {:ok, state} =
      Engine.init(schema, uischema, %{"flag" => false, "enabled" => true, "name" => "Ada"}, %{})

    assert state.rule_state[render_key][:visible?] == false

    {:ok, state} =
      Engine.init(schema, uischema, %{"flag" => false, "enabled" => false, "name" => "Ada"}, %{})

    assert state.rule_state[render_key][:visible?] == true
  end

  test "leaf condition matches expected value" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "mode" => %{"type" => "string"},
        "name" => %{"type" => "string"}
      }
    }

    uischema = %{
      "type" => "Control",
      "scope" => "#/properties/name",
      "rule" => %{
        "effect" => "HIDE",
        "condition" => %{
          "type" => "LEAF",
          "scope" => "#/properties/mode",
          "expectedValue" => "advanced"
        }
      }
    }

    element_key = Rules.element_key(uischema, [])
    render_key = Rules.render_key(element_key, "name")

    {:ok, state} = Engine.init(schema, uischema, %{"mode" => "advanced"}, %{})
    assert state.rule_state[render_key][:visible?] == false

    {:ok, state} = Engine.init(schema, uischema, %{"mode" => "basic"}, %{})
    assert state.rule_state[render_key][:visible?] == true
  end

  test "not condition inverts the child condition" do
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
          "type" => "NOT",
          "condition" => %{
            "scope" => "#/properties/flag",
            "schema" => %{"const" => true}
          }
        }
      }
    }

    element_key = Rules.element_key(uischema, [])
    render_key = Rules.render_key(element_key, "name")

    {:ok, state} = Engine.init(schema, uischema, %{"flag" => true}, %{})
    assert state.rule_state[render_key][:visible?] == false

    {:ok, state} = Engine.init(schema, uischema, %{"flag" => false}, %{})
    assert state.rule_state[render_key][:visible?] == true
  end

  test "evaluate_incremental updates only affected rules" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "flag" => %{"type" => "boolean"},
        "count" => %{"type" => "number"},
        "name" => %{"type" => "string"},
        "age" => %{"type" => "number"}
      }
    }

    name_control = %{
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

    age_control = %{
      "type" => "Control",
      "scope" => "#/properties/age",
      "rule" => %{
        "effect" => "HIDE",
        "condition" => %{
          "scope" => "#/properties/count",
          "schema" => %{"minimum" => 10}
        }
      }
    }

    uischema = %{
      "type" => "VerticalLayout",
      "elements" => [name_control, age_control]
    }

    data = %{"flag" => false, "count" => 0, "name" => "Ada", "age" => 30}
    {:ok, state} = Engine.init(schema, uischema, data, %{})
    rule_index = Rules.index(uischema)

    name_key = Rules.render_key(Rules.element_key(name_control, [0]), "name")
    age_key = Rules.render_key(Rules.element_key(age_control, [1]), "age")

    assert state.rule_state[name_key][:visible?] == true
    assert state.rule_state[age_key][:visible?] == true

    data = %{"flag" => true, "count" => 10, "name" => "Ada", "age" => 30}

    {rule_state, _cache} =
      Rules.evaluate_incremental(
        rule_index,
        state.rule_state,
        ["flag"],
        data,
        state.validator,
        state.validator_opts,
        state.rule_schema_cache || %{}
      )

    assert rule_state[name_key][:visible?] == false
    assert rule_state[age_key][:visible?] == true
  end

  test "rule condition $ref uses validate_fragment" do
    uischema = %{
      "type" => "Control",
      "scope" => "#/properties/name",
      "rule" => %{
        "effect" => "HIDE",
        "condition" => %{
          "scope" => "#/properties/flag",
          "schema" => %{"$ref" => "#/definitions/flagTrue"}
        }
      }
    }

    data = %{"flag" => true, "name" => "Ada"}

    validator = %{module: JsonFormsLV.RulesRefValidator, compiled: :compiled}
    {rule_state, _cache} = Rules.evaluate(uischema, data, validator, [], %{})

    render_key = Rules.render_key(Rules.element_key(uischema, []), "name")
    assert rule_state[render_key][:visible?] == false

    assert_receive {:validate_fragment, :compiled, "#/definitions/flagTrue", true}
  end
end
