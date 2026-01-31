defmodule JsonFormsLV.FormGroupTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.{FormGroup, Engine}

  test "init builds shared data for forms" do
    schema = %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}

    {:ok, group} =
      FormGroup.init([
        %{
          id: :a,
          schema: schema,
          uischema: %{"type" => "Control", "scope" => "#/properties/name"}
        },
        %{
          id: :b,
          schema: schema,
          uischema: %{"type" => "Control", "scope" => "#/properties/name"}
        }
      ])

    assert %{} = group.data
    assert FormGroup.state(group, :a).schema == schema
    assert FormGroup.state(group, :b).schema == schema
  end

  test "dispatch propagates data to other forms" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string"},
        "age" => %{"type" => "number"}
      }
    }

    uischema_a = %{"type" => "Control", "scope" => "#/properties/name"}
    uischema_b = %{"type" => "Control", "scope" => "#/properties/age"}

    {:ok, group} =
      FormGroup.init([
        %{id: :a, schema: schema, uischema: uischema_a},
        %{id: :b, schema: schema, uischema: uischema_b}
      ])

    {:ok, group} = FormGroup.dispatch(group, :a, {:update_data, "name", "Ada", %{}})

    assert FormGroup.state(group, :a).data["name"] == "Ada"
    assert FormGroup.state(group, :b).data["name"] == "Ada"
  end

  test "apply_external_data revalidates" do
    schema = %{
      "type" => "object",
      "properties" => %{"name" => %{"type" => "string", "minLength" => 2}}
    }

    {:ok, state} = Engine.init(schema, %{}, %{"name" => "Ada"}, %{})

    {:ok, state} = Engine.apply_external_data(state, %{"name" => ""}, ["name"])

    assert Enum.any?(state.errors, &(&1.keyword == "minLength"))
  end
end
