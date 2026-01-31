defmodule JsonFormsLvDemoWeb.DemoLive do
  use JsonFormsLvDemoWeb, :live_view

  alias JsonFormsLV.{Data, Engine, Event}

  import JsonFormsLV.Phoenix.Components, only: [json_forms: 1]

  @impl true
  def mount(_params, _session, socket) do
    config = scenario_config("basic")

    {:ok, state} =
      Engine.init(config.schema, config.uischema, config.data, %{
        validation_mode: config.validation_mode
      })

    socket =
      socket
      |> assign(:scenario, "basic")
      |> assign(:schema, config.schema)
      |> assign(:uischema, config.uischema)
      |> assign(:state, state)
      |> assign(:data, state.data)
      |> assign(:form, to_form(%{}, as: :jf))
      |> assign(:current_scope, nil)
      |> assign(:readonly, config.readonly)
      |> assign(:locale, config.locale)
      |> assign(:i18n, config.i18n)
      |> assign(:validation_mode, config.validation_mode)
      |> assign(:json_forms_opts, config.json_forms_opts)

    socket = maybe_sync_array_streams(socket, state, config)

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
    config = scenario_config(scenario)

    case Engine.init(config.schema, config.uischema, config.data, %{
           validation_mode: config.validation_mode
         }) do
      {:ok, state} ->
        socket =
          socket
          |> assign(:scenario, scenario)
          |> assign(:schema, config.schema)
          |> assign(:uischema, config.uischema)
          |> assign(:state, state)
          |> assign(:data, state.data)
          |> assign(:form, to_form(%{}, as: :jf))
          |> assign(:readonly, config.readonly)
          |> assign(:locale, config.locale)
          |> assign(:i18n, config.i18n)
          |> assign(:validation_mode, config.validation_mode)
          |> assign(:json_forms_opts, config.json_forms_opts)

        socket = maybe_sync_array_streams(socket, state, config)

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("set_locale", %{"locale" => locale}, socket) do
    locale = locale |> String.trim() |> String.downcase()

    {:noreply,
     socket
     |> assign(:locale, locale)
     |> assign(:i18n, demo_i18n(locale))}
  end

  def handle_event("toggle_readonly", _params, socket) do
    {:noreply, assign(socket, :readonly, not socket.assigns.readonly)}
  end

  def handle_event("jf:add_item", %{"path" => path}, socket) do
    case Engine.add_item(socket.assigns.state, path, %{}) do
      {:ok, state} ->
        socket = assign(socket, state: state, data: state.data)
        {:noreply, maybe_sync_array_streams(socket, state)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("jf:remove_item", %{"path" => path, "index" => index}, socket) do
    case Engine.remove_item(socket.assigns.state, path, index) do
      {:ok, state} ->
        socket = assign(socket, state: state, data: state.data)
        {:noreply, maybe_sync_array_streams(socket, state)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("jf:move_item", %{"path" => path, "from" => from, "to" => to}, socket) do
    case Engine.move_item(socket.assigns.state, path, from, to) do
      {:ok, state} ->
        socket = assign(socket, state: state, data: state.data)
        {:noreply, maybe_sync_array_streams(socket, state)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("set_validation_mode", %{"mode" => mode}, socket) do
    validation_mode =
      case String.trim(mode) do
        "validate_and_show" -> :validate_and_show
        "validate_and_hide" -> :validate_and_hide
        "no_validation" -> :no_validation
        _ -> socket.assigns.validation_mode
      end

    {:ok, state} = Engine.set_validation_mode(socket.assigns.state, validation_mode)

    {:noreply, assign(socket, validation_mode: validation_mode, state: state)}
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
            <button
              id="scenario-formats"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="formats"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "formats" && "bg-zinc-900 text-white",
                @scenario != "formats" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Formats
            </button>
            <button
              id="scenario-arrays"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="arrays"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "arrays" && "bg-zinc-900 text-white",
                @scenario != "arrays" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Arrays
            </button>
            <button
              id="scenario-i18n"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="i18n"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "i18n" && "bg-zinc-900 text-white",
                @scenario != "i18n" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              I18n
            </button>
            <button
              id="scenario-readonly"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="readonly"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "readonly" && "bg-zinc-900 text-white",
                @scenario != "readonly" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Readonly
            </button>
            <button
              id="scenario-readonly-precedence"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="readonly-precedence"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "readonly-precedence" && "bg-zinc-900 text-white",
                @scenario != "readonly-precedence" &&
                  "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Readonly precedence
            </button>
            <button
              id="scenario-validation"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="validation"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "validation" && "bg-zinc-900 text-white",
                @scenario != "validation" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Validation
            </button>
          </div>

          <%= if @scenario == "i18n" do %>
            <div class="flex flex-wrap items-center gap-2" id="demo-locale-toggle">
              <span id="demo-locale" class="text-xs font-semibold uppercase text-zinc-500">
                Locale: {@locale}
              </span>
              <button
                id="locale-en"
                type="button"
                phx-click="set_locale"
                phx-value-locale="en"
                class={[
                  "rounded-full px-3 py-1 text-xs font-semibold transition",
                  @locale == "en" && "bg-zinc-900 text-white",
                  @locale != "en" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
                ]}
              >
                EN
              </button>
              <button
                id="locale-es"
                type="button"
                phx-click="set_locale"
                phx-value-locale="es"
                class={[
                  "rounded-full px-3 py-1 text-xs font-semibold transition",
                  @locale == "es" && "bg-zinc-900 text-white",
                  @locale != "es" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
                ]}
              >
                ES
              </button>
            </div>
          <% end %>

          <%= if @scenario in ["readonly", "readonly-precedence"] do %>
            <button
              id="demo-readonly-toggle"
              type="button"
              phx-click="toggle_readonly"
              class="rounded-full px-3 py-1 text-xs font-semibold transition bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
            >
              Toggle readonly
            </button>
          <% end %>

          <%= if @scenario == "validation" do %>
            <div class="flex flex-wrap items-center gap-2" id="demo-validation-toggle">
              <span
                id="demo-validation-mode"
                class="text-xs font-semibold uppercase text-zinc-500"
              >
                Mode: {@validation_mode}
              </span>
              <button
                id="validation-show"
                type="button"
                phx-click="set_validation_mode"
                phx-value-mode="validate_and_show"
                class={[
                  "rounded-full px-3 py-1 text-xs font-semibold transition",
                  @validation_mode == :validate_and_show && "bg-zinc-900 text-white",
                  @validation_mode != :validate_and_show &&
                    "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
                ]}
              >
                Show
              </button>
              <button
                id="validation-hide"
                type="button"
                phx-click="set_validation_mode"
                phx-value-mode="validate_and_hide"
                class={[
                  "rounded-full px-3 py-1 text-xs font-semibold transition",
                  @validation_mode == :validate_and_hide && "bg-zinc-900 text-white",
                  @validation_mode != :validate_and_hide &&
                    "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
                ]}
              >
                Hide
              </button>
              <button
                id="validation-off"
                type="button"
                phx-click="set_validation_mode"
                phx-value-mode="no_validation"
                class={[
                  "rounded-full px-3 py-1 text-xs font-semibold transition",
                  @validation_mode == :no_validation && "bg-zinc-900 text-white",
                  @validation_mode != :no_validation &&
                    "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
                ]}
              >
                Off
              </button>
            </div>
          <% end %>

          <.form for={@form} id="demo-json-forms-form" phx-change="jf:change" phx-submit="jf:submit">
            <.json_forms
              id="demo-json-forms"
              schema={@schema}
              uischema={@uischema}
              data={@data}
              state={@state}
              readonly={@readonly}
              i18n={@i18n}
              validation_mode={@validation_mode}
              binding={:form_level}
              opts={@json_forms_opts}
              streams={assigns[:streams]}
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
          <pre
            id="debug-uischema"
            class="rounded-lg bg-zinc-900 text-zinc-100 p-4 text-xs overflow-auto"
          >
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

  defp formats_schema do
    %{
      "type" => "object",
      "required" => ["status", "priority", "start_date"],
      "properties" => %{
        "status" => %{
          "type" => "string",
          "title" => "Status",
          "description" => "Current status",
          "enum" => ["active", "paused", "closed"]
        },
        "priority" => %{
          "type" => "integer",
          "title" => "Priority",
          "enum" => [1, 2, 3]
        },
        "start_date" => %{
          "type" => "string",
          "title" => "Start date",
          "format" => "date",
          "minLength" => 10
        },
        "meeting" => %{
          "type" => "string",
          "title" => "Meeting time",
          "format" => "date-time"
        },
        "notes" => %{
          "type" => "string",
          "title" => "Notes"
        }
      }
    }
  end

  defp arrays_schema do
    %{
      "type" => "object",
      "properties" => %{
        "tasks" => %{
          "type" => "array",
          "title" => "Tasks",
          "items" => %{
            "type" => "object",
            "default" => %{"title" => "", "done" => false},
            "properties" => %{
              "title" => %{"type" => "string", "title" => "Title"},
              "done" => %{"type" => "boolean", "title" => "Done"}
            }
          }
        }
      }
    }
  end

  defp formats_uischema do
    %{
      "type" => "Group",
      "label" => "Project details",
      "i18n" => "project",
      "elements" => [
        %{
          "type" => "Label",
          "text" => "Schedule",
          "id" => "i18n-welcome",
          "i18n" => "project.schedule"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/status",
          "options" => %{"format" => "radio"}
        },
        %{"type" => "Control", "scope" => "#/properties/priority"},
        %{"type" => "Control", "scope" => "#/properties/start_date"},
        %{"type" => "Control", "scope" => "#/properties/meeting"},
        %{
          "type" => "Control",
          "scope" => "#/properties/notes",
          "options" => %{"multi" => true}
        }
      ]
    }
  end

  defp arrays_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Control",
          "scope" => "#/properties/tasks",
          "options" => %{"showSortButtons" => true, "elementLabelProp" => "title"}
        }
      ]
    }
  end

  defp readonly_schema do
    %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string", "title" => "Name"},
        "code" => %{"type" => "string", "title" => "Immutable", "readOnly" => true},
        "note" => %{"type" => "string", "title" => "Note"}
      }
    }
  end

  defp readonly_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{"type" => "Control", "scope" => "#/properties/name"},
        %{"type" => "Control", "scope" => "#/properties/code"},
        %{
          "type" => "Control",
          "scope" => "#/properties/note",
          "options" => %{"readOnly" => true}
        }
      ]
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
    base_config(%{
      schema: rules_schema(),
      uischema: rules_uischema(),
      data: %{"show_details" => false, "details" => "Secret"}
    })
  end

  defp scenario_config("formats") do
    base_config(%{
      schema: formats_schema(),
      uischema: formats_uischema(),
      data: %{
        "status" => "active",
        "priority" => 1,
        "start_date" => "2025-01-30",
        "meeting" => "2025-01-30T10:00",
        "notes" => ""
      }
    })
  end

  defp scenario_config("arrays") do
    base_config(%{
      schema: arrays_schema(),
      uischema: arrays_uischema(),
      data: %{
        "tasks" => [
          %{"title" => "Plan", "done" => false},
          %{"title" => "Build", "done" => true}
        ]
      },
      json_forms_opts: %{
        stream_arrays: true,
        stream_names: %{"tasks" => :tasks}
      }
    })
  end

  defp scenario_config("i18n") do
    base_config(%{
      schema: formats_schema(),
      uischema: formats_uischema(),
      data: %{
        "status" => "active",
        "priority" => 1,
        "start_date" => "2025-01-30",
        "meeting" => "2025-01-30T10:00",
        "notes" => ""
      },
      locale: "en",
      i18n: demo_i18n("en")
    })
  end

  defp scenario_config("readonly") do
    base_config(%{
      schema: readonly_schema(),
      uischema: readonly_uischema(),
      data: %{"name" => "Ada", "code" => "READ-ONLY", "note" => "Locked"},
      readonly: true
    })
  end

  defp scenario_config("readonly-precedence") do
    base_config(%{
      schema: readonly_schema(),
      uischema: readonly_uischema(),
      data: %{"name" => "Ada", "code" => "READ-ONLY", "note" => "Locked"},
      readonly: false
    })
  end

  defp scenario_config("validation") do
    base_config(%{
      schema: demo_schema(),
      uischema: demo_uischema(),
      data: %{"name" => "", "age" => 32, "subscribed" => true},
      validation_mode: :validate_and_show
    })
  end

  defp scenario_config(_scenario) do
    base_config(%{
      schema: demo_schema(),
      uischema: demo_uischema(),
      data: %{"name" => "Ada", "age" => 32, "subscribed" => true}
    })
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

  defp base_config(overrides) do
    Map.merge(
      %{
        schema: %{},
        uischema: %{},
        data: %{},
        readonly: false,
        locale: nil,
        i18n: %{},
        validation_mode: :validate_and_show,
        json_forms_opts: %{}
      },
      overrides
    )
  end

  defp demo_i18n(locale) do
    %{
      locale: locale,
      translate: fn key, default, _ctx ->
        Map.get(demo_translations(locale), key, default)
      end
    }
  end

  defp demo_translations("es") do
    %{
      "project.label" => "Detalles del proyecto",
      "project.schedule.text" => "Horario",
      "status.label" => "Estado",
      "status.description" => "Estado actual",
      "status.active" => "Activo",
      "status.paused" => "En pausa",
      "status.closed" => "Cerrado",
      "priority.label" => "Prioridad",
      "priority.1" => "Baja",
      "priority.2" => "Media",
      "priority.3" => "Alta",
      "start_date.label" => "Fecha de inicio",
      "meeting.label" => "Hora de reunion",
      "notes.label" => "Notas"
    }
  end

  defp demo_translations(_locale), do: %{}

  defp maybe_sync_array_streams(socket, state, config \\ nil) do
    opts =
      cond do
        is_map(config) -> Map.get(config, :json_forms_opts, %{})
        is_map(socket.assigns.json_forms_opts) -> socket.assigns.json_forms_opts
        true -> %{}
      end

    stream_arrays? =
      Map.get(opts, :stream_arrays, false) || Map.get(opts, "stream_arrays", false)

    stream_names = Map.get(opts, :stream_names, %{}) || Map.get(opts, "stream_names", %{})

    if stream_arrays? and is_map(stream_names) and map_size(stream_names) > 0 do
      Enum.reduce(stream_names, socket, fn {path, name}, socket ->
        items = array_stream_items(state, path)
        stream(socket, name, items, reset: true)
      end)
    else
      socket
    end
  end

  defp array_stream_items(state, path) do
    items =
      case Data.get(state.data, path) do
        {:ok, list} when is_list(list) -> list
        _ -> []
      end

    ids = Map.get(state.array_ids || %{}, path, [])

    Enum.with_index(items)
    |> Enum.map(fn {_item, index} ->
      item_id = Enum.at(ids, index) || Integer.to_string(index)

      %{
        id: stream_dom_id(path, item_id),
        index: index
      }
    end)
  end

  defp stream_dom_id(path, item_id) do
    base = if path == "", do: "root", else: path
    "jf-stream-#{sanitize_id(base)}-#{sanitize_id(item_id)}"
  end

  defp sanitize_id(value) do
    value
    |> to_string()
    |> String.replace(".", "-")
    |> String.replace(~r/[^A-Za-z0-9_-]/, "-")
  end
end
