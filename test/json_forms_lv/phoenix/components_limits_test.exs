defmodule JsonFormsLV.Phoenix.ComponentsLimitsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonFormsLV.Engine
  alias JsonFormsLV.Phoenix.Components

  defp render_forms(opts) do
    render_component(&Components.json_forms/1, opts)
  end

  test "max_elements renders unknown when exceeded" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string"},
        "age" => %{"type" => "number"}
      }
    }

    uischema = %{
      "type" => "VerticalLayout",
      "elements" => [
        %{"type" => "Control", "scope" => "#/properties/name"},
        %{"type" => "Control", "scope" => "#/properties/age"}
      ]
    }

    {:ok, state} = Engine.init(schema, uischema, %{"name" => "Ada", "age" => 30}, %{})

    html =
      render_forms(
        id: "limits",
        schema: schema,
        uischema: uischema,
        data: state.data,
        state: state,
        opts: %{max_elements: 1},
        wrap_form: false
      )

    assert html =~ "Max render elements exceeded"
  end

  test "max_depth renders unknown when exceeded" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string"}
      }
    }

    uischema = %{
      "type" => "VerticalLayout",
      "elements" => [
        %{"type" => "Control", "scope" => "#/properties/name"}
      ]
    }

    {:ok, state} = Engine.init(schema, uischema, %{"name" => "Ada"}, %{})

    html =
      render_forms(
        id: "depth",
        schema: schema,
        uischema: uischema,
        data: state.data,
        state: state,
        opts: %{max_depth: 0},
        wrap_form: false
      )

    assert html =~ "Max render depth exceeded"
  end
end
