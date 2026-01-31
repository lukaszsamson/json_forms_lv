defmodule JsonFormsLV.Phoenix.ArrayControlTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonFormsLV.{Engine, Registry}
  alias JsonFormsLV.Phoenix.Renderers.ArrayControl

  defp base_assigns(state, uischema, options, config) do
    tasks_schema = state.schema["properties"]["tasks"]

    %{
      id: "tasks",
      state: state,
      registry: Registry.new(),
      uischema: uischema,
      schema: tasks_schema,
      root_schema: state.schema,
      data: state.data,
      path: "tasks",
      instance_path: "/tasks",
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
      config: config
    }
  end

  defp state_fixture do
    schema = %{
      "type" => "object",
      "properties" => %{
        "tasks" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "title" => %{"type" => "string"},
              "note" => %{"type" => "string"}
            }
          }
        }
      }
    }

    data = %{"tasks" => [%{"title" => "Plan", "note" => "First"}]}
    uischema = %{"type" => "Control", "scope" => "#/properties/tasks"}

    {:ok, state} = Engine.init(schema, uischema, data, %{})
    {state, uischema}
  end

  test "detail DEFAULT renders all properties" do
    {state, uischema} = state_fixture()

    assigns =
      base_assigns(state, uischema, %{"detail" => "DEFAULT"}, %{})

    html = render_component(&ArrayControl.render/1, assigns)

    assert html =~ "name=\"tasks.0.note\""
    assert html =~ "name=\"tasks.0.title\""
  end

  test "detail GENERATED renders all properties" do
    {state, uischema} = state_fixture()

    assigns =
      base_assigns(state, uischema, %{"detail" => "GENERATED"}, %{})

    html = render_component(&ArrayControl.render/1, assigns)

    assert html =~ "name=\"tasks.0.note\""
    assert html =~ "name=\"tasks.0.title\""
  end

  test "detail REGISTERED uses registry paths" do
    {state, uischema} = state_fixture()

    registry = %{
      "task_detail" => %{
        "type" => "VerticalLayout",
        "elements" => [
          %{"type" => "Control", "scope" => "#/properties/title"}
        ]
      }
    }

    assigns =
      base_assigns(
        state,
        uischema,
        %{"detail" => "REGISTERED", "detailKey" => "task_detail"},
        %{detail_registry: registry}
      )

    html = render_component(&ArrayControl.render/1, assigns)

    assert html =~ "name=\"tasks.0.title\""
    refute html =~ "name=\"tasks.0.note\""
  end
end
