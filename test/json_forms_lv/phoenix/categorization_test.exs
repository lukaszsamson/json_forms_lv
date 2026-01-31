defmodule JsonFormsLV.Phoenix.CategorizationTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonFormsLV.{Engine, Rules}
  alias JsonFormsLV.Phoenix.Components

  defp render_forms(opts) do
    render_component(&Components.json_forms/1, opts)
  end

  test "categorization renders tabs and panels" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "profile" => %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"},
            "title" => %{"type" => "string"}
          }
        },
        "project" => %{
          "type" => "object",
          "properties" => %{
            "status" => %{"type" => "string", "enum" => ["active", "paused"]}
          }
        }
      }
    }

    uischema = %{
      "type" => "Categorization",
      "options" => %{"defaultCategory" => 0},
      "elements" => [
        %{
          "type" => "Category",
          "label" => "Profile",
          "elements" => [
            %{"type" => "Control", "scope" => "#/properties/profile/properties/name"},
            %{"type" => "Control", "scope" => "#/properties/profile/properties/title"}
          ]
        },
        %{
          "type" => "Category",
          "label" => "Project",
          "elements" => [
            %{"type" => "Control", "scope" => "#/properties/project/properties/status"}
          ]
        }
      ]
    }

    {:ok, state} =
      Engine.init(
        schema,
        uischema,
        %{"profile" => %{"name" => "Ada", "title" => "Engineer"}, "project" => %{}},
        %{}
      )

    html =
      render_forms(
        id: "categorization",
        schema: schema,
        uischema: uischema,
        data: state.data,
        state: state,
        wrap_form: false
      )

    assert html =~ ~r/role="tablist"/
    assert html =~ ~r/role="tab"/
    assert html =~ ~r/role="tabpanel"/
    assert html =~ ~r/aria-selected="true"/
    assert html =~ ~r/display: none;/
  end

  test "categorization uses server state for active tab" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "profile" => %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"},
            "title" => %{"type" => "string"}
          }
        },
        "project" => %{
          "type" => "object",
          "properties" => %{
            "status" => %{"type" => "string", "enum" => ["active", "paused"]}
          }
        }
      }
    }

    uischema = %{
      "type" => "Categorization",
      "options" => %{"defaultCategory" => 0},
      "elements" => [
        %{
          "type" => "Category",
          "label" => "Profile",
          "elements" => [
            %{"type" => "Control", "scope" => "#/properties/profile/properties/name"}
          ]
        },
        %{
          "type" => "Category",
          "label" => "Project",
          "elements" => [
            %{"type" => "Control", "scope" => "#/properties/project/properties/status"}
          ]
        }
      ]
    }

    {:ok, state} =
      Engine.init(
        schema,
        uischema,
        %{"profile" => %{"name" => "Ada"}, "project" => %{}},
        %{}
      )

    key = Rules.render_key(Rules.element_key(uischema, []), "")

    html =
      render_forms(
        id: "categorization",
        schema: schema,
        uischema: uischema,
        data: state.data,
        state: state,
        opts: %{categorization_state: %{key => 1}},
        wrap_form: false
      )

    assert html =~ ~r/-panel-0"[^>]*style="display: none;"/
  end
end
