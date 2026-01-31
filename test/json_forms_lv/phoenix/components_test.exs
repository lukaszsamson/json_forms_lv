defmodule JsonFormsLV.Phoenix.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonFormsLV.{Engine, Phoenix.Components}

  defp render_forms(opts) do
    render_component(&Components.json_forms/1, opts)
  end

  test "hidden parent hides children" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "flag" => %{"type" => "boolean"},
        "name" => %{"type" => "string"}
      }
    }

    uischema = %{
      "type" => "VerticalLayout",
      "rule" => %{
        "effect" => "HIDE",
        "condition" => %{
          "scope" => "#/properties/flag",
          "schema" => %{"const" => true}
        }
      },
      "elements" => [
        %{"type" => "Control", "scope" => "#/properties/name"}
      ]
    }

    {:ok, state} = Engine.init(schema, uischema, %{"flag" => true, "name" => "Ada"}, %{})

    html =
      render_forms(
        id: "hidden-parent",
        schema: schema,
        uischema: uischema,
        data: state.data,
        state: state,
        wrap_form: false
      )

    refute html =~ ~r/name="name"/
  end

  test "disabled parent disables children" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "flag" => %{"type" => "boolean"},
        "name" => %{"type" => "string"}
      }
    }

    uischema = %{
      "type" => "VerticalLayout",
      "rule" => %{
        "effect" => "DISABLE",
        "condition" => %{
          "scope" => "#/properties/flag",
          "schema" => %{"const" => true}
        }
      },
      "elements" => [
        %{"type" => "Control", "scope" => "#/properties/name"}
      ]
    }

    {:ok, state} = Engine.init(schema, uischema, %{"flag" => true, "name" => "Ada"}, %{})

    html =
      render_forms(
        id: "disabled-parent",
        schema: schema,
        uischema: uischema,
        data: state.data,
        state: state,
        wrap_form: false
      )

    assert html =~ ~r/name="name"/
    assert html =~ ~r/<input[^>]*name="name"[^>]*disabled/
  end

  test "readonly disables regardless of rule enable" do
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

    {:ok, state} = Engine.init(schema, uischema, %{"flag" => true, "name" => "Ada"}, %{})

    html =
      render_forms(
        id: "readonly-rule",
        schema: schema,
        uischema: uischema,
        data: state.data,
        state: state,
        readonly: true,
        wrap_form: false
      )

    assert html =~ ~r/<input[^>]*name="name"[^>]*disabled/
  end

  test "schema readOnly overrides rule enable" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "flag" => %{"type" => "boolean"},
        "name" => %{"type" => "string", "readOnly" => true}
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

    {:ok, state} = Engine.init(schema, uischema, %{"flag" => true, "name" => "Ada"}, %{})

    html =
      render_forms(
        id: "schema-readonly",
        schema: schema,
        uischema: uischema,
        data: state.data,
        state: state,
        wrap_form: false
      )

    assert html =~ ~r/<input[^>]*name="name"[^>]*disabled/
  end

  test "uischema options.readOnly overrides rule enable" do
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
      "options" => %{"readOnly" => true},
      "rule" => %{
        "effect" => "ENABLE",
        "condition" => %{
          "scope" => "#/properties/flag",
          "schema" => %{"const" => true}
        }
      }
    }

    {:ok, state} = Engine.init(schema, uischema, %{"flag" => true, "name" => "Ada"}, %{})

    html =
      render_forms(
        id: "uischema-readonly",
        schema: schema,
        uischema: uischema,
        data: state.data,
        state: state,
        wrap_form: false
      )

    assert html =~ ~r/<input[^>]*name="name"[^>]*disabled/
  end
end
