defmodule JsonFormsLV.TelemetryTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.{Dispatch, Engine, Registry}

  test "emits engine and dispatch telemetry events" do
    handler_id = "telemetry-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      [
        [:json_forms_lv, :init],
        [:json_forms_lv, :update_data],
        [:json_forms_lv, :validate],
        [:json_forms_lv, :dispatch]
      ],
      fn event, measurements, metadata, _ ->
        send(self(), {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    schema = %{
      "type" => "object",
      "properties" => %{"name" => %{"type" => "string", "minLength" => 1}}
    }

    uischema = %{"type" => "Control", "scope" => "#/properties/name"}

    {:ok, state} = Engine.init(schema, uischema, %{"name" => "Ada"}, %{})

    assert_receive {:telemetry, [:json_forms_lv, :init], _measurements, _metadata}
    assert_receive {:telemetry, [:json_forms_lv, :validate], _measurements, _metadata}

    {:ok, _state} = Engine.update_data(state, "name", "", %{})

    assert_receive {:telemetry, [:json_forms_lv, :update_data], _measurements, metadata}
    assert metadata.path == "name"

    registry = Registry.new(control_renderers: [], layout_renderers: [], cell_renderers: [])
    Dispatch.pick_renderer(uischema, schema, registry, %{}, :control)

    assert_receive {:telemetry, [:json_forms_lv, :dispatch], _measurements, _metadata}
  end
end
