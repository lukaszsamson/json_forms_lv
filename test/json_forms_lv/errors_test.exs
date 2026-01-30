defmodule JsonFormsLV.ErrorsTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.{Error, Errors, State}

  test "normalize_additional converts AJV-like maps" do
    [error] =
      Errors.normalize_additional([
        %{"instancePath" => "/name", "message" => "Required"}
      ])

    assert %Error{instance_path: "/name", message: "Required", source: :additional} = error
  end

  test "errors_for_control respects touched gating" do
    error = %Error{instance_path: "/name", message: "Invalid", source: :validator}

    state = %State{
      validation_mode: :validate_and_show,
      touched: MapSet.new(),
      submitted: false,
      errors: [error],
      opts: %{}
    }

    assert Errors.errors_for_control(state, "name") == []

    state = %State{state | touched: MapSet.new(["name"])}
    assert length(Errors.errors_for_control(state, "name")) == 1
  end

  test "additional errors are shown by default" do
    error = %Error{instance_path: "/name", message: "Invalid", source: :additional}

    state = %State{
      validation_mode: :no_validation,
      touched: MapSet.new(),
      submitted: false,
      errors: [error],
      opts: %{}
    }

    assert length(Errors.errors_for_control(state, "name")) == 1
  end
end
