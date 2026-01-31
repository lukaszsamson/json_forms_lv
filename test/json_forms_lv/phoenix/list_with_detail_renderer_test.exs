defmodule JsonFormsLV.Phoenix.ListWithDetailRendererTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonFormsLV.Engine
  alias JsonFormsLV.Phoenix.Renderers.ListWithDetail
  alias JsonFormsLV.Registry

  defp base_assigns(state, uischema, options) do
    users_schema = state.schema["properties"]["users"]

    %{
      id: "users",
      state: state,
      registry: Registry.new(),
      uischema: uischema,
      schema: users_schema,
      root_schema: state.schema,
      data: state.data,
      path: "users",
      instance_path: "/users",
      visible?: true,
      enabled?: true,
      readonly?: false,
      required?: false,
      show_errors?: false,
      options: options,
      i18n: %{},
      ctx: %{},
      binding: :per_input,
      streams: nil,
      renderer_opts: [],
      on_change: "jf:change",
      on_blur: "jf:blur",
      on_submit: "jf:submit",
      target: nil,
      config: %{}
    }
  end

  defp state_fixture do
    schema = %{
      "type" => "object",
      "properties" => %{
        "users" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "firstname" => %{"type" => "string"},
              "lastname" => %{"type" => "string"}
            }
          }
        }
      }
    }

    data = %{"users" => [%{"firstname" => "Ada", "lastname" => "Lovelace"}]}
    uischema = %{"type" => "ListWithDetail", "scope" => "#/properties/users"}

    {:ok, state} = Engine.init(schema, uischema, data, %{})
    {state, uischema}
  end

  test "renders list with detail items" do
    {state, uischema} = state_fixture()

    assigns = base_assigns(state, uischema, %{"detail" => "DEFAULT"})

    html = render_component(&ListWithDetail.render/1, assigns)

    assert html =~ "jf-list-detail"
    assert html =~ "<details"
    assert html =~ "name=\"users.0.firstname\""
    assert html =~ "name=\"users.0.lastname\""
  end
end
