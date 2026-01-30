defmodule JsonFormsLvDemoWeb.DemoLive do
  use JsonFormsLvDemoWeb, :live_view

  alias JsonFormsLV.{Engine, Event}

  import JsonFormsLV.Phoenix.Components, only: [json_forms: 1]

  @impl true
  def mount(_params, _session, socket) do
    schema = demo_schema()
    uischema = demo_uischema()
    data = %{"name" => "Ada", "age" => 32, "subscribed" => true}

    {:ok, state} = Engine.init(schema, uischema, data, %{})

    socket =
      socket
      |> assign(:schema, schema)
      |> assign(:uischema, uischema)
      |> assign(:state, state)
      |> assign(:data, state.data)
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

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6">
        <div class="space-y-2">
          <h1 class="text-2xl font-semibold">JSON Forms LiveView Demo</h1>
          <p class="text-sm text-zinc-600">Basic schema-driven form rendering.</p>
        </div>

        <div class="space-y-4">
          <.json_forms
            id="demo-json-forms"
            schema={@schema}
            uischema={@uischema}
            data={@data}
            state={@state}
          />
        </div>

        <div class="space-y-2">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-600">Data</h2>
          <pre id="debug-data" class="rounded-lg bg-zinc-900 text-zinc-100 p-4 text-xs overflow-auto">
            {Jason.encode!(@data, pretty: true)}
          </pre>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp demo_schema do
    %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string", "title" => "Name"},
        "age" => %{"type" => "integer", "title" => "Age"},
        "subscribed" => %{"type" => "boolean", "title" => "Subscribed"}
      }
    }
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
