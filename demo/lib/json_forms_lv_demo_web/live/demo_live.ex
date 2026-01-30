defmodule JsonFormsLvDemoWeb.DemoLive do
  use JsonFormsLvDemoWeb, :live_view

  alias JsonFormsLV.{Engine, Event}

  import JsonFormsLV.Phoenix.Components, only: [json_forms: 1]

  @impl true
  def mount(_params, _session, socket) do
    {schema, uischema, data} = scenario_config("basic")

    {:ok, state} = Engine.init(schema, uischema, data, %{})

    socket =
      socket
      |> assign(:scenario, "basic")
      |> assign(:schema, schema)
      |> assign(:uischema, uischema)
      |> assign(:state, state)
      |> assign(:data, state.data)
      |> assign(:form, to_form(%{}, as: :jf))
      |> assign(:current_scope, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("jf:change", params, socket) do
    case Event.extract_change(params) do
      {:ok, %{path: path, value: value, meta: meta}} ->
        case Engine.update_data(socket.assigns.state, path, value, meta) do
          {:ok, state} ->
            {:noreply, assign(socket, state: state, data: state.data)}

          {:error, _reason} ->
            {:noreply, socket}
        end

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("jf:blur", params, socket) do
    case Event.extract_blur(params) do
      {:ok, %{path: path}} ->
        {:ok, state} = Engine.touch(socket.assigns.state, path)
        {:noreply, assign(socket, state: state)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("jf:submit", _params, socket) do
    {:ok, state} = Engine.touch_all(socket.assigns.state)
    {:noreply, assign(socket, state: state)}
  end

  def handle_event("select_scenario", %{"scenario" => scenario}, socket) do
    scenario = scenario |> String.trim() |> String.downcase()
    {schema, uischema, data} = scenario_config(scenario)

    case Engine.init(schema, uischema, data, %{}) do
      {:ok, state} ->
        socket =
          socket
          |> assign(:scenario, scenario)
          |> assign(:schema, schema)
          |> assign(:uischema, uischema)
          |> assign(:state, state)
          |> assign(:data, state.data)
          |> assign(:form, to_form(%{}, as: :jf))

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6">
        <div class="space-y-2">
          <h1 class="text-2xl font-semibold">JSON Forms LiveView Demo</h1>
          <p class="text-sm text-zinc-600">Basic schema-driven form rendering.</p>
          <p id="demo-scenario" class="text-xs font-semibold uppercase tracking-wide text-zinc-500">
            Scenario: {@scenario}
          </p>
        </div>

        <div class="space-y-4">
          <div class="flex flex-wrap gap-2" id="demo-scenarios">
            <button
              id="scenario-basic"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="basic"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "basic" && "bg-zinc-900 text-white",
                @scenario != "basic" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Basic
            </button>
            <button
              id="scenario-rules"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="rules"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "rules" && "bg-zinc-900 text-white",
                @scenario != "rules" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Rules
            </button>
          </div>

          <.form for={@form} id="demo-json-forms-form" phx-submit="jf:submit">
            <.json_forms
              id="demo-json-forms"
              schema={@schema}
              uischema={@uischema}
              data={@data}
              state={@state}
              wrap_form={false}
            />

            <button
              id="demo-json-forms-submit"
              type="submit"
              class="rounded-md bg-zinc-900 px-4 py-2 text-sm font-semibold text-white"
            >
              Submit
            </button>
          </.form>
        </div>

        <%= if @state.submitted do %>
          <div class="space-y-2">
            <p id="demo-submit-status" class="text-sm font-semibold text-zinc-800">
              Submitted
            </p>

            <%= if @state.errors != [] do %>
              <ul id="demo-submit-errors" class="jf-errors text-sm text-red-600">
                <%= for error <- @state.errors do %>
                  <li>{error.message}</li>
                <% end %>
              </ul>
            <% end %>
          </div>
        <% end %>

        <div class="space-y-2">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-600">Data</h2>
          <pre id="debug-data" class="rounded-lg bg-zinc-900 text-zinc-100 p-4 text-xs overflow-auto">
            {Jason.encode!(@data, pretty: true)}
          </pre>
        </div>

        <div class="space-y-2">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-600">Errors</h2>
          <pre
            id="debug-errors"
            class="rounded-lg bg-zinc-900 text-zinc-100 p-4 text-xs overflow-auto"
          >
            {Jason.encode!(Enum.map(@state.errors, &Map.from_struct/1), pretty: true)}
          </pre>
        </div>

        <div class="space-y-2">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-600">Rules</h2>
          <pre id="debug-rules" class="rounded-lg bg-zinc-900 text-zinc-100 p-4 text-xs overflow-auto">
            {Jason.encode!(@state.rule_state, pretty: true)}
          </pre>
        </div>

        <div class="space-y-2">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-600">UISchema</h2>
          <pre id="debug-uischema" class="rounded-lg bg-zinc-900 text-zinc-100 p-4 text-xs overflow-auto">
            {Jason.encode!(@state.uischema, pretty: true)}
          </pre>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp demo_schema do
    %{
      "type" => "object",
      "required" => ["name"],
      "properties" => %{
        "name" => %{
          "type" => "string",
          "title" => "Name",
          "minLength" => 1,
          "description" => "Required"
        },
        "age" => %{"type" => "integer", "title" => "Age", "minimum" => 0},
        "subscribed" => %{"type" => "boolean", "title" => "Subscribed"}
      }
    }
  end

  defp rules_schema do
    %{
      "type" => "object",
      "properties" => %{
        "show_details" => %{"type" => "boolean", "title" => "Show details", "default" => false},
        "details" => %{"type" => "string", "title" => "Details", "minLength" => 1}
      }
    }
  end

  defp rules_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Control",
          "scope" => "#/properties/show_details",
          "id" => "show-details-control"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/details",
          "id" => "details-control",
          "rule" => %{
            "effect" => "HIDE",
            "condition" => %{
              "scope" => "#/properties/show_details",
              "schema" => %{"const" => false}
            }
          }
        }
      ]
    }
  end

  defp scenario_config("rules") do
    {rules_schema(), rules_uischema(), %{"show_details" => false, "details" => "Secret"}}
  end

  defp scenario_config(_scenario) do
    {demo_schema(), demo_uischema(), %{"name" => "Ada", "age" => 32, "subscribed" => true}}
  end

  defp demo_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{"type" => "Control", "scope" => "#/properties/name"},
        %{"type" => "Control", "scope" => "#/properties/age"},
        %{"type" => "Control", "scope" => "#/properties/subscribed"}
      ]
    }
  end
end
