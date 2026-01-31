defmodule JsonFormsLvDemoWeb.StorybookLive do
  @moduledoc """
  Storybook showcasing JSON Forms examples from jsonforms.io
  """
  use JsonFormsLvDemoWeb, :live_view

  alias JsonFormsLV.{Engine, Event}

  import JsonFormsLV.Phoenix.Components, only: [json_forms: 1]

  @scenarios [
    {"basic", "Basic"},
    {"control", "Control"},
    {"categorization", "Categorization"},
    {"layouts", "Layouts"},
    {"array", "Array"},
    {"rule", "Rule"},
    {"custom-controls", "Custom Controls"},
    {"combinators", "Combinators"},
    {"list-with-detail", "List With Detail"},
    {"autocomplete-enum", "Autocomplete Enum"},
    {"autocomplete-oneof", "Autocomplete OneOf"},
    {"gen-uischema", "Gen UI Schema"},
    {"gen-both", "Gen Both"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    config = scenario_config("basic")

    {:ok, state} = Engine.init(config.schema, config.uischema, config.data, %{})

    socket =
      socket
      |> assign(:scenario, "basic")
      |> assign(:scenarios, @scenarios)
      |> assign(:schema, config.schema)
      |> assign(:uischema, config.uischema)
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
    config = scenario_config(scenario)

    case Engine.init(config.schema, config.uischema, config.data, %{}) do
      {:ok, state} ->
        socket =
          socket
          |> assign(:scenario, scenario)
          |> assign(:schema, config.schema)
          |> assign(:uischema, config.uischema)
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
          <h1 class="text-2xl font-semibold">JSON Forms Storybook</h1>
          <p class="text-sm text-zinc-600">
            Examples from <a href="https://jsonforms.io/examples" class="underline text-blue-600" target="_blank">jsonforms.io/examples</a>
          </p>
          <p id="storybook-scenario" class="text-xs font-semibold uppercase tracking-wide text-zinc-500">
            Scenario: {@scenario}
          </p>
        </div>

        <div class="space-y-4">
          <div class="flex flex-wrap gap-2" id="storybook-scenarios">
            <%= for {scenario_id, scenario_label} <- @scenarios do %>
              <button
                id={"scenario-#{scenario_id}"}
                type="button"
                phx-click="select_scenario"
                phx-value-scenario={scenario_id}
                class={[
                  "rounded-full px-3 py-1 text-sm font-semibold transition",
                  @scenario == scenario_id && "bg-zinc-900 text-white",
                  @scenario != scenario_id && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
                ]}
              >
                {scenario_label}
              </button>
            <% end %>
          </div>

          <.form for={@form} id="storybook-json-forms-form" phx-submit="jf:submit">
            <.json_forms
              id="storybook-json-forms"
              schema={@schema}
              uischema={@uischema}
              data={@data}
              state={@state}
              wrap_form={false}
            />

            <button
              id="storybook-json-forms-submit"
              type="submit"
              class="rounded-md bg-zinc-900 px-4 py-2 text-sm font-semibold text-white mt-4"
            >
              Submit
            </button>
          </.form>
        </div>

        <%= if @state.submitted do %>
          <div class="space-y-2">
            <p id="storybook-submit-status" class="text-sm font-semibold text-zinc-800">
              Submitted
            </p>

            <%= if @state.errors != [] do %>
              <ul id="storybook-submit-errors" class="jf-errors text-sm text-red-600">
                <%= for error <- @state.errors do %>
                  <li>{error.message}</li>
                <% end %>
              </ul>
            <% end %>
          </div>
        <% end %>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <div class="space-y-2">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-600">Data</h2>
            <pre id="debug-data" class="rounded-lg bg-zinc-900 text-zinc-100 p-4 text-xs overflow-auto max-h-64">{Jason.encode!(@data, pretty: true)}</pre>
          </div>

          <div class="space-y-2">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-600">Errors</h2>
            <pre id="debug-errors" class="rounded-lg bg-zinc-900 text-zinc-100 p-4 text-xs overflow-auto max-h-64">{Jason.encode!(Enum.map(@state.errors, &Map.from_struct/1), pretty: true)}</pre>
          </div>

          <div class="space-y-2">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-600">Schema</h2>
            <pre id="debug-schema" class="rounded-lg bg-zinc-900 text-zinc-100 p-4 text-xs overflow-auto max-h-64">{Jason.encode!(@schema, pretty: true)}</pre>
          </div>

          <div class="space-y-2">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-600">UISchema</h2>
            <pre id="debug-uischema" class="rounded-lg bg-zinc-900 text-zinc-100 p-4 text-xs overflow-auto max-h-64">{Jason.encode!(@uischema, pretty: true)}</pre>
          </div>
        </div>

        <div class="space-y-2">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-600">Rules State</h2>
          <pre id="debug-rules" class="rounded-lg bg-zinc-900 text-zinc-100 p-4 text-xs overflow-auto max-h-64">{Jason.encode!(@state.rule_state, pretty: true)}</pre>
        </div>
      </section>
    </Layouts.app>
    """
  end

  # ============================================================================
  # Scenario Configurations
  # ============================================================================

  defp scenario_config("basic"), do: base_config(basic_example())
  defp scenario_config("control"), do: base_config(control_example())
  defp scenario_config("categorization"), do: base_config(categorization_example())
  defp scenario_config("layouts"), do: base_config(layouts_example())
  defp scenario_config("array"), do: base_config(array_example())
  defp scenario_config("rule"), do: base_config(rule_example())
  defp scenario_config("custom-controls"), do: base_config(custom_controls_example())
  defp scenario_config("combinators"), do: base_config(combinators_example())
  defp scenario_config("list-with-detail"), do: base_config(list_with_detail_example())
  defp scenario_config("autocomplete-enum"), do: base_config(autocomplete_enum_example())
  defp scenario_config("autocomplete-oneof"), do: base_config(autocomplete_oneof_example())
  defp scenario_config("gen-uischema"), do: base_config(gen_uischema_example())
  defp scenario_config("gen-both"), do: base_config(gen_both_example())
  defp scenario_config(_), do: base_config(basic_example())

  defp base_config(example) do
    Map.merge(%{schema: %{}, uischema: %{}, data: %{}}, example)
  end

  # ============================================================================
  # Basic Example (jsonforms.io/examples/basic)
  # ============================================================================

  defp basic_example do
    %{
      schema: %{
        "type" => "object",
        "properties" => %{
          "name" => %{
            "type" => "string",
            "minLength" => 3,
            "description" => "Please enter your name"
          },
          "vegetarian" => %{"type" => "boolean"},
          "birthDate" => %{"type" => "string", "format" => "date"},
          "nationality" => %{
            "type" => "string",
            "enum" => ["DE", "IT", "JP", "US", "RU", "Other"]
          },
          "personalData" => %{
            "type" => "object",
            "properties" => %{
              "age" => %{"type" => "integer", "description" => "Please enter your age."},
              "height" => %{"type" => "number"},
              "drivingSkill" => %{
                "type" => "number",
                "maximum" => 10,
                "minimum" => 1,
                "default" => 7
              }
            },
            "required" => ["age", "height"]
          },
          "occupation" => %{"type" => "string"},
          "postalCode" => %{"type" => "string", "maxLength" => 5}
        },
        "required" => ["occupation", "nationality"]
      },
      uischema: %{
        "type" => "VerticalLayout",
        "elements" => [
          %{
            "type" => "HorizontalLayout",
            "elements" => [
              %{"type" => "Control", "scope" => "#/properties/name"},
              %{"type" => "Control", "scope" => "#/properties/personalData/properties/age"},
              %{"type" => "Control", "scope" => "#/properties/birthDate"}
            ]
          },
          %{"type" => "Label", "text" => "Additional Information"},
          %{
            "type" => "HorizontalLayout",
            "elements" => [
              %{"type" => "Control", "scope" => "#/properties/personalData/properties/height"},
              %{"type" => "Control", "scope" => "#/properties/nationality"},
              %{
                "type" => "Control",
                "scope" => "#/properties/occupation",
                "options" => %{
                  "suggestion" => [
                    "Accountant",
                    "Engineer",
                    "Freelancer",
                    "Journalism",
                    "Physician",
                    "Student",
                    "Teacher",
                    "Other"
                  ]
                }
              }
            ]
          }
        ]
      },
      data: %{
        "name" => "John Doe",
        "vegetarian" => false,
        "birthDate" => "1985-06-02",
        "personalData" => %{"age" => 34},
        "postalCode" => "12345"
      }
    }
  end

  # ============================================================================
  # Control Example (jsonforms.io/examples/control)
  # ============================================================================

  defp control_example do
    %{
      schema: %{
        "type" => "object",
        "properties" => %{
          "string" => %{"type" => "string"},
          "boolean" => %{"type" => "boolean", "description" => "Boolean description as a tooltip"},
          "number" => %{"type" => "number"},
          "integer" => %{"type" => "integer"},
          "date" => %{"type" => "string", "format" => "date"},
          "time" => %{"type" => "string", "format" => "time"},
          "dateTime" => %{"type" => "string", "format" => "date-time"},
          "enum" => %{"type" => "string", "enum" => ["One", "Two", "Three"]}
        }
      },
      uischema: %{
        "type" => "VerticalLayout",
        "elements" => [
          %{"type" => "Control", "scope" => "#/properties/string"},
          %{"type" => "Control", "scope" => "#/properties/boolean"},
          %{"type" => "Control", "scope" => "#/properties/number"},
          %{"type" => "Control", "scope" => "#/properties/integer"},
          %{"type" => "Control", "scope" => "#/properties/date"},
          %{"type" => "Control", "scope" => "#/properties/time"},
          %{"type" => "Control", "scope" => "#/properties/dateTime"},
          %{"type" => "Control", "scope" => "#/properties/enum"}
        ]
      },
      data: %{
        "string" => "This is a string",
        "boolean" => true,
        "number" => 50.5,
        "integer" => 50,
        "date" => "2020-06-25",
        "time" => "23:08:00",
        "dateTime" => "2020-06-25T23:08:42",
        "enum" => "Two"
      }
    }
  end

  # ============================================================================
  # Categorization Example (jsonforms.io/examples/categorization)
  # ============================================================================

  defp categorization_example do
    %{
      schema: %{
        "type" => "object",
        "properties" => %{
          "firstName" => %{
            "type" => "string",
            "minLength" => 3,
            "description" => "Please enter your first name"
          },
          "secondName" => %{
            "type" => "string",
            "minLength" => 3,
            "description" => "Please enter your second name"
          },
          "vegetarian" => %{"type" => "boolean"},
          "birthDate" => %{
            "type" => "string",
            "format" => "date",
            "description" => "Please enter your birth date."
          },
          "nationality" => %{
            "type" => "string",
            "enum" => ["DE", "IT", "JP", "US", "RU", "Other"]
          },
          "provideAddress" => %{"type" => "boolean"},
          "address" => %{
            "type" => "object",
            "properties" => %{
              "street" => %{"type" => "string"},
              "streetNumber" => %{"type" => "string"},
              "city" => %{"type" => "string"},
              "postalCode" => %{"type" => "string", "maxLength" => 5}
            }
          },
          "vegetarianOptions" => %{
            "type" => "object",
            "properties" => %{
              "vegan" => %{"type" => "boolean"},
              "favoriteVegetable" => %{
                "type" => "string",
                "enum" => ["Tomato", "Potato", "Salad", "Aubergine", "Cucumber", "Other"]
              },
              "otherFavoriteVegetable" => %{"type" => "string"}
            }
          }
        }
      },
      uischema: %{
        "type" => "Categorization",
        "elements" => [
          %{
            "type" => "Category",
            "label" => "Personal Info",
            "elements" => [
              %{
                "type" => "HorizontalLayout",
                "elements" => [
                  %{"type" => "Control", "scope" => "#/properties/firstName"},
                  %{"type" => "Control", "scope" => "#/properties/secondName"}
                ]
              },
              %{
                "type" => "HorizontalLayout",
                "elements" => [
                  %{"type" => "Control", "scope" => "#/properties/birthDate"},
                  %{"type" => "Control", "scope" => "#/properties/nationality"}
                ]
              },
              %{"type" => "Control", "scope" => "#/properties/provideAddress"},
              %{"type" => "Control", "scope" => "#/properties/vegetarian"}
            ]
          },
          %{
            "type" => "Category",
            "label" => "Address",
            "elements" => [
              %{
                "type" => "HorizontalLayout",
                "elements" => [
                  %{"type" => "Control", "scope" => "#/properties/address/properties/street"},
                  %{"type" => "Control", "scope" => "#/properties/address/properties/streetNumber"}
                ]
              },
              %{
                "type" => "HorizontalLayout",
                "elements" => [
                  %{"type" => "Control", "scope" => "#/properties/address/properties/city"},
                  %{"type" => "Control", "scope" => "#/properties/address/properties/postalCode"}
                ]
              }
            ],
            "rule" => %{
              "effect" => "SHOW",
              "condition" => %{
                "scope" => "#/properties/provideAddress",
                "schema" => %{"const" => true}
              }
            }
          },
          %{
            "type" => "Category",
            "label" => "Additional",
            "elements" => [
              %{"type" => "Control", "scope" => "#/properties/vegetarianOptions/properties/vegan"},
              %{
                "type" => "Control",
                "scope" => "#/properties/vegetarianOptions/properties/favoriteVegetable"
              },
              %{
                "type" => "Control",
                "scope" => "#/properties/vegetarianOptions/properties/otherFavoriteVegetable",
                "rule" => %{
                  "effect" => "SHOW",
                  "condition" => %{
                    "scope" => "#/properties/vegetarianOptions/properties/favoriteVegetable",
                    "schema" => %{"const" => "Other"}
                  }
                }
              }
            ],
            "rule" => %{
              "effect" => "SHOW",
              "condition" => %{
                "scope" => "#/properties/vegetarian",
                "schema" => %{"const" => true}
              }
            }
          }
        ]
      },
      data: %{
        "provideAddress" => true,
        "vegetarian" => false
      }
    }
  end

  # ============================================================================
  # Layouts Example (jsonforms.io/examples/layouts)
  # ============================================================================

  defp layouts_example do
    %{
      schema: %{
        "type" => "object",
        "properties" => %{
          "name" => %{
            "type" => "string",
            "minLength" => 3,
            "description" => "Please enter your name"
          },
          "vegetarian" => %{"type" => "boolean"},
          "birthDate" => %{"type" => "string", "format" => "date"},
          "nationality" => %{
            "type" => "string",
            "enum" => ["DE", "IT", "JP", "US", "RU", "Other"]
          },
          "personalData" => %{
            "type" => "object",
            "properties" => %{
              "age" => %{"type" => "integer", "description" => "Please enter your age."},
              "height" => %{"type" => "number"},
              "drivingSkill" => %{
                "type" => "number",
                "maximum" => 10,
                "minimum" => 1,
                "default" => 7
              }
            },
            "required" => ["age", "height"]
          },
          "occupation" => %{"type" => "string"},
          "postalCode" => %{"type" => "string", "maxLength" => 5}
        },
        "required" => ["occupation", "nationality"]
      },
      uischema: %{
        "type" => "Group",
        "label" => "My Group",
        "elements" => [
          %{
            "type" => "HorizontalLayout",
            "elements" => [
              %{
                "type" => "VerticalLayout",
                "elements" => [
                  %{"type" => "Control", "label" => "Name", "scope" => "#/properties/name"},
                  %{"type" => "Control", "label" => "Birth Date", "scope" => "#/properties/birthDate"}
                ]
              },
              %{
                "type" => "VerticalLayout",
                "elements" => [
                  %{"type" => "Control", "label" => "Name", "scope" => "#/properties/name"},
                  %{"type" => "Control", "label" => "Birth Date", "scope" => "#/properties/birthDate"}
                ]
              }
            ]
          }
        ]
      },
      data: %{
        "name" => "John Doe",
        "vegetarian" => false,
        "birthDate" => "1985-06-02",
        "personalData" => %{"age" => 34},
        "postalCode" => "12345"
      }
    }
  end

  # ============================================================================
  # Array Example (jsonforms.io/examples/array)
  # ============================================================================

  defp array_example do
    %{
      schema: %{
        "type" => "object",
        "properties" => %{
          "comments" => %{
            "type" => "array",
            "items" => %{
              "type" => "object",
              "properties" => %{
                "date" => %{"type" => "string", "format" => "date"},
                "message" => %{"type" => "string", "maxLength" => 5},
                "enum" => %{"type" => "string", "enum" => ["foo", "bar"]}
              }
            }
          }
        }
      },
      uischema: %{
        "type" => "VerticalLayout",
        "elements" => [
          %{"type" => "Control", "scope" => "#/properties/comments"}
        ]
      },
      data: %{
        "comments" => [
          %{"date" => "2001-09-11", "message" => "This is an example message"},
          %{"date" => "2026-01-02", "message" => "Get ready for booohay"}
        ]
      }
    }
  end

  # ============================================================================
  # Rule Example (jsonforms.io/examples/rule)
  # ============================================================================

  defp rule_example do
    %{
      schema: %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "dead" => %{"type" => "boolean"},
          "kindOfDead" => %{
            "type" => "string",
            "enum" => ["Zombie", "Vampire", "Ghoul"]
          },
          "vegetables" => %{"type" => "boolean"},
          "kindOfVegetables" => %{
            "type" => "string",
            "enum" => ["All", "Some", "Only potatoes"]
          },
          "vitaminDeficiency" => %{
            "type" => "string",
            "enum" => ["None", "Vitamin A", "Vitamin B", "Vitamin C"]
          }
        }
      },
      uischema: %{
        "type" => "VerticalLayout",
        "elements" => [
          %{"type" => "Control", "label" => "Name", "scope" => "#/properties/name"},
          %{
            "type" => "Group",
            "elements" => [
              %{"type" => "Control", "label" => "Is Dead?", "scope" => "#/properties/dead"},
              %{
                "type" => "Control",
                "label" => "Kind of dead",
                "scope" => "#/properties/kindOfDead",
                "rule" => %{
                  "effect" => "ENABLE",
                  "condition" => %{
                    "scope" => "#/properties/dead",
                    "schema" => %{"const" => true}
                  }
                }
              }
            ]
          },
          %{
            "type" => "Group",
            "elements" => [
              %{
                "type" => "Control",
                "label" => "Eats vegetables?",
                "scope" => "#/properties/vegetables"
              },
              %{
                "type" => "Control",
                "label" => "Kind of vegetables",
                "scope" => "#/properties/kindOfVegetables",
                "rule" => %{
                  "effect" => "HIDE",
                  "condition" => %{
                    "scope" => "#/properties/vegetables",
                    "schema" => %{"const" => false}
                  }
                }
              },
              %{
                "type" => "Control",
                "label" => "Vitamin deficiency?",
                "scope" => "#/properties/vitaminDeficiency"
              }
            ]
          }
        ]
      },
      data: %{
        "name" => "John Doe",
        "dead" => false,
        "vegetables" => false
      }
    }
  end

  # ============================================================================
  # Custom Controls Example (jsonforms.io/examples/custom-controls)
  # ============================================================================

  defp custom_controls_example do
    %{
      schema: %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string", "default" => "foo"},
          "name_noDefault" => %{"type" => "string"},
          "description" => %{"type" => "string", "default" => "bar"},
          "done" => %{"type" => "boolean", "default" => false},
          "rating" => %{"type" => "integer", "default" => 5},
          "cost" => %{"type" => "number", "default" => 5.5},
          "dueDate" => %{"type" => "string", "format" => "date", "default" => "2019-04-01"}
        },
        "required" => ["name", "name_noDefault"]
      },
      uischema: %{
        "type" => "VerticalLayout",
        "elements" => [
          %{"type" => "Control", "scope" => "#/properties/name"},
          %{"type" => "Control", "scope" => "#/properties/name_noDefault"},
          %{"type" => "Control", "label" => false, "scope" => "#/properties/done"},
          %{
            "type" => "Control",
            "scope" => "#/properties/description",
            "options" => %{"multi" => true}
          },
          %{"type" => "Control", "scope" => "#/properties/rating"},
          %{"type" => "Control", "scope" => "#/properties/cost"},
          %{"type" => "Control", "scope" => "#/properties/dueDate"}
        ]
      },
      data: %{
        "name" => "Send email to Adrian",
        "name_noDefault" => "Send email to Adrian",
        "description" => "Confirm if you have passed the subject\nHereby ...",
        "done" => true,
        "rating" => 1,
        "cost" => 3.14,
        "dueDate" => "2019-05-01"
      }
    }
  end

  # ============================================================================
  # Combinators Example (jsonforms.io/examples/combinators)
  # ============================================================================

  defp combinators_example do
    %{
      schema: %{
        "definitions" => %{
          "address" => %{
            "type" => "object",
            "title" => "Address",
            "properties" => %{
              "street_address" => %{"type" => "string"},
              "city" => %{"type" => "string"},
              "state" => %{"type" => "string"}
            },
            "required" => ["street_address", "city", "state"]
          },
          "user" => %{
            "type" => "object",
            "title" => "User",
            "properties" => %{
              "name" => %{"type" => "string"},
              "mail" => %{"type" => "string"}
            },
            "required" => ["name", "mail"]
          }
        },
        "type" => "object",
        "properties" => %{
          "addressOrUser" => %{
            "oneOf" => [
              %{"$ref" => "#/definitions/address"},
              %{"$ref" => "#/definitions/user"}
            ]
          }
        }
      },
      uischema: %{
        "type" => "VerticalLayout",
        "elements" => [
          %{
            "type" => "Control",
            "label" => "Basic Information",
            "scope" => "#/properties/addressOrUser"
          }
        ]
      },
      data: %{
        "addressOrUser" => %{
          "street_address" => "1600 Pennsylvania Avenue NW",
          "city" => "Washington",
          "state" => "DC"
        }
      }
    }
  end

  # ============================================================================
  # List With Detail Example (jsonforms.io/examples/list-with-detail)
  # ============================================================================

  defp list_with_detail_example do
    %{
      schema: %{
        "type" => "object",
        "properties" => %{
          "users" => %{
            "type" => "array",
            "items" => %{
              "type" => "object",
              "title" => "Users",
              "properties" => %{
                "firstname" => %{"type" => "string"},
                "lastname" => %{"type" => "string"},
                "email" => %{"type" => "string", "format" => "email"},
                "age" => %{"type" => "number", "minimum" => 0}
              },
              "required" => ["firstname"]
            }
          }
        }
      },
      uischema: %{
        "type" => "ListWithDetail",
        "scope" => "#/properties/users",
        "options" => %{
          "detail" => %{
            "type" => "VerticalLayout",
            "elements" => [
              %{
                "type" => "HorizontalLayout",
                "elements" => [
                  %{
                    "type" => "Control",
                    "scope" => "#/properties/firstname",
                    "label" => "First Name"
                  },
                  %{"type" => "Control", "scope" => "#/properties/lastname", "label" => "Last Name"}
                ]
              },
              %{"type" => "Control", "scope" => "#/properties/age", "label" => "Age"},
              %{"type" => "Control", "scope" => "#/properties/email", "label" => "Email"}
            ]
          }
        }
      },
      data: %{
        "users" => [
          %{
            "firstname" => "Max",
            "lastname" => "Mustermann",
            "age" => 25,
            "email" => "max@mustermann.com"
          },
          %{"firstname" => "John", "lastname" => "Doe", "age" => 35, "email" => "john@doe.com"}
        ]
      }
    }
  end

  # ============================================================================
  # Autocomplete Enum Example (jsonforms.io/examples/autocomplete)
  # ============================================================================

  defp autocomplete_enum_example do
    %{
      schema: %{
        "type" => "object",
        "properties" => %{
          "autocompleteEnum" => %{
            "type" => "string",
            "enum" => ["foo", "bar", "foobar"]
          }
        }
      },
      uischema: %{
        "type" => "VerticalLayout",
        "elements" => [
          %{
            "type" => "Control",
            "scope" => "#/properties/autocompleteEnum",
            "options" => %{"autocomplete" => true}
          }
        ]
      },
      data: %{}
    }
  end

  # ============================================================================
  # Autocomplete OneOf Example (jsonforms.io/examples/autocomplete)
  # ============================================================================

  defp autocomplete_oneof_example do
    %{
      schema: %{
        "type" => "object",
        "properties" => %{
          "autocompleteOneOf" => %{
            "type" => "string",
            "oneOf" => [
              %{"const" => "foo", "title" => "Foo"},
              %{"const" => "bar", "title" => "Bar"},
              %{"const" => "foobar", "title" => "FooBar"}
            ]
          }
        }
      },
      uischema: %{
        "type" => "VerticalLayout",
        "elements" => [
          %{
            "type" => "Control",
            "scope" => "#/properties/autocompleteOneOf",
            "options" => %{"autocomplete" => true}
          }
        ]
      },
      data: %{}
    }
  end

  # ============================================================================
  # Generate UI Schema Example (jsonforms.io/examples/gen-uischema)
  # ============================================================================

  defp gen_uischema_example do
    %{
      schema: %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "vegetarian" => %{"type" => "boolean"},
          "birthDate" => %{"type" => "string"},
          "personalData" => %{
            "type" => "object",
            "properties" => %{
              "age" => %{"type" => "integer"}
            },
            "additionalProperties" => true,
            "required" => ["age"]
          },
          "postalCode" => %{"type" => "string"}
        },
        "additionalProperties" => true,
        "required" => ["name", "vegetarian", "birthDate", "personalData", "postalCode"]
      },
      uischema: %{
        "type" => "VerticalLayout",
        "elements" => [
          %{"type" => "Control", "scope" => "#/properties/name"},
          %{"type" => "Control", "scope" => "#/properties/vegetarian"},
          %{"type" => "Control", "scope" => "#/properties/birthDate"},
          %{"type" => "Control", "scope" => "#/properties/personalData"},
          %{"type" => "Control", "scope" => "#/properties/postalCode"}
        ]
      },
      data: %{
        "name" => "John Doe",
        "vegetarian" => false,
        "birthDate" => "1985-06-02",
        "personalData" => %{"age" => 34},
        "postalCode" => "12345"
      }
    }
  end

  # ============================================================================
  # Generate Both Schemas Example (jsonforms.io/examples/gen-both-schemas)
  # ============================================================================

  defp gen_both_example do
    %{
      schema: %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"},
          "vegetarian" => %{"type" => "boolean"},
          "birthDate" => %{"type" => "string"},
          "personalData" => %{
            "type" => "object",
            "properties" => %{
              "age" => %{"type" => "integer"}
            },
            "additionalProperties" => true,
            "required" => ["age"]
          },
          "postalCode" => %{"type" => "string"}
        },
        "additionalProperties" => true,
        "required" => ["name", "vegetarian", "birthDate", "personalData", "postalCode"]
      },
      uischema: %{},
      data: %{
        "name" => "John Doe",
        "vegetarian" => false,
        "birthDate" => "1985-06-02",
        "personalData" => %{"age" => 34},
        "postalCode" => "12345"
      }
    }
  end
end
