defmodule JsonFormsLV.Phoenix.LiveComponentTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.{Engine, State}
  alias JsonFormsLV.Phoenix.LiveComponent

  defp socket(state) do
    %Phoenix.LiveView.Socket{
      assigns: %{state: state, opts: %{}, notify: self(), __changed__: %{}}
    }
  end

  test "jf:change notifies parent" do
    schema = %{
      "type" => "object",
      "properties" => %{"name" => %{"type" => "string"}}
    }

    uischema = %{"type" => "Control", "scope" => "#/properties/name"}
    {:ok, state} = Engine.init(schema, uischema, %{"name" => "Ada"}, %{})

    {:noreply, _socket} =
      LiveComponent.handle_event(
        "jf:change",
        %{"_target" => ["jf", "name"], "jf" => %{"name" => "Grace"}},
        socket(state)
      )

    assert_receive {:json_forms_lv, :change, %State{data: %{"name" => "Grace"}}}
  end

  test "jf:blur notifies parent" do
    schema = %{
      "type" => "object",
      "properties" => %{"name" => %{"type" => "string"}}
    }

    uischema = %{"type" => "Control", "scope" => "#/properties/name"}
    {:ok, state} = Engine.init(schema, uischema, %{"name" => "Ada"}, %{})

    {:noreply, _socket} =
      LiveComponent.handle_event(
        "jf:blur",
        %{"_target" => ["jf", "name"]},
        socket(state)
      )

    assert_receive {:json_forms_lv, :blur, %State{touched: touched}}
    assert MapSet.member?(touched, "name")
  end

  test "jf:submit notifies parent" do
    schema = %{
      "type" => "object",
      "properties" => %{"name" => %{"type" => "string"}}
    }

    uischema = %{"type" => "Control", "scope" => "#/properties/name"}
    {:ok, state} = Engine.init(schema, uischema, %{"name" => "Ada"}, %{})

    {:noreply, _socket} = LiveComponent.handle_event("jf:submit", %{}, socket(state))

    assert_receive {:json_forms_lv, :submit, %State{submitted: true}}
  end
end
