defmodule JsonFormsLvDemoWeb.DemoLive do
  use JsonFormsLvDemoWeb, :live_view

  alias JsonFormsLV.{Engine, Event, FormGroup}
  alias JsonFormsLV.Phoenix.StreamSync

  import JsonFormsLV.Phoenix.Components, only: [json_forms: 1]

  @impl true
  def mount(_params, _session, socket) do
    config = scenario_config("basic")

    engine_opts = Map.merge(%{validation_mode: config.validation_mode}, config.json_forms_opts)

    {:ok, state} = Engine.init(config.schema, config.uischema, config.data, engine_opts)

    {:ok, state} = maybe_set_additional_errors(state, config.additional_errors)

    display_state = if config.form_group_a, do: config.form_group_a, else: state
    display_data = if config.form_group, do: config.form_group.data, else: state.data

    socket =
      socket
      |> assign(:scenario, "basic")
      |> assign(:schema, display_state.schema)
      |> assign(:uischema, display_state.uischema)
      |> assign(:state, display_state)
      |> assign(:data, display_data)
      |> assign(:form, to_form(%{}, as: :jf))
      |> assign(:form_a, to_form(%{}, as: :jf_a))
      |> assign(:form_b, to_form(%{}, as: :jf_b))
      |> assign(:current_scope, nil)
      |> assign(:readonly, config.readonly)
      |> assign(:locale, config.locale)
      |> assign(:i18n, config.i18n)
      |> assign(:validation_mode, config.validation_mode)
      |> assign(:json_forms_opts, config.json_forms_opts)
      |> assign(:json_forms_cells, config.json_forms_cells)
      |> assign(:json_forms_renderers, config.json_forms_renderers)
      |> assign(:additional_errors, config.additional_errors)
      |> assign(:form_group, config.form_group)
      |> assign(:form_group_a, config.form_group_a)
      |> assign(:form_group_b, config.form_group_b)
      |> assign(:interlinked_version_a, 0)
      |> assign(:interlinked_version_b, 0)

    socket = maybe_sync_array_streams(socket, nil, state, config)

    {:ok, socket}
  end

  @impl true
  def handle_event("jf:change", params, socket) do
    case Event.extract_change(params) do
      {:ok, %{path: path, value: value, meta: meta}} ->
        case Engine.update_data(socket.assigns.state, path, value, meta) do
          {:ok, state} ->
            old_state = socket.assigns.state
            socket = assign(socket, state: state, data: state.data)
            {:noreply, maybe_sync_array_streams(socket, old_state, state)}

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

    engine_opts = Map.merge(%{validation_mode: config.validation_mode}, config.json_forms_opts)

    case Engine.init(config.schema, config.uischema, config.data, engine_opts) do
      {:ok, state} ->
        {:ok, state} = maybe_set_additional_errors(state, config.additional_errors)
        old_state = socket.assigns[:state]
        display_state = if config.form_group_a, do: config.form_group_a, else: state
        display_data = if config.form_group, do: config.form_group.data, else: state.data

        socket =
          socket
          |> assign(:scenario, scenario)
          |> assign(:schema, display_state.schema)
          |> assign(:uischema, display_state.uischema)
          |> assign(:state, display_state)
          |> assign(:data, display_data)
          |> assign(:form, to_form(%{}, as: :jf))
          |> assign(:form_a, to_form(%{}, as: :jf_a))
          |> assign(:form_b, to_form(%{}, as: :jf_b))
          |> assign(:readonly, config.readonly)
          |> assign(:locale, config.locale)
          |> assign(:i18n, config.i18n)
          |> assign(:validation_mode, config.validation_mode)
          |> assign(:json_forms_opts, config.json_forms_opts)
          |> assign(:json_forms_cells, config.json_forms_cells)
          |> assign(:json_forms_renderers, config.json_forms_renderers)
          |> assign(:additional_errors, config.additional_errors)
          |> assign(:form_group, config.form_group)
          |> assign(:form_group_a, config.form_group_a)
          |> assign(:form_group_b, config.form_group_b)
          |> assign(:interlinked_version_a, 0)
          |> assign(:interlinked_version_b, 0)

        socket = maybe_sync_array_streams(socket, old_state, state, config)

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("form_group_change", %{"form" => form} = params, socket) do
    form_id = form_group_id(form)
    form_key = if form_id == :a, do: "jf_a", else: "jf_b"

    with %FormGroup{} = group <- socket.assigns.form_group,
         {:ok, %{path: path, value: value, meta: meta}} <-
           Event.extract_change(params, form_key: form_key),
         {:ok, group} <- FormGroup.dispatch(group, form_id, {:update_data, path, value, meta}) do
      # Only update the version of the OTHER form to force refresh while keeping focus on active form
      version_key = if form_id == :a, do: :interlinked_version_b, else: :interlinked_version_a

      socket =
        socket
        |> assign(:form_group, group)
        |> assign(:form_group_a, FormGroup.state(group, :a))
        |> assign(:form_group_b, FormGroup.state(group, :b))
        |> assign(:state, FormGroup.state(group, :a))
        |> assign(:data, group.data)
        |> update(version_key, &((&1 || 0) + 1))

      {:noreply, socket}
    else
      _ -> {:noreply, socket}
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
        old_state = socket.assigns.state
        socket = assign(socket, state: state, data: state.data)
        {:noreply, maybe_sync_array_streams(socket, old_state, state)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("jf:remove_item", %{"path" => path, "index" => index}, socket) do
    case Engine.remove_item(socket.assigns.state, path, index) do
      {:ok, state} ->
        old_state = socket.assigns.state
        socket = assign(socket, state: state, data: state.data)
        {:noreply, maybe_sync_array_streams(socket, old_state, state)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("jf:move_item", %{"path" => path, "from" => from, "to" => to}, socket) do
    case Engine.move_item(socket.assigns.state, path, from, to) do
      {:ok, state} ->
        old_state = socket.assigns.state
        socket = assign(socket, state: state, data: state.data)
        {:noreply, maybe_sync_array_streams(socket, old_state, state)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("jf:select_combinator", %{"path" => path} = params, socket) do
    selection = Map.get(params, "selection") || Map.get(params, "value")
    kind = Map.get(params, "kind")

    # For oneOf, clear data when switching tabs; anyOf just switches view without clearing
    opts = if kind == "one_of", do: %{clear_data: true}, else: %{}

    {:ok, state} = Engine.set_combinator(socket.assigns.state, path, selection, opts)
    {:noreply, assign(socket, state: state, data: state.data)}
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
          <p class="text-sm text-zinc-600">
            Schema-driven forms with validation, rules, i18n, layouts, arrays, and custom renderers.
          </p>
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
              id="scenario-suggestions"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="suggestions"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "suggestions" && "bg-zinc-900 text-white",
                @scenario != "suggestions" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Suggestions
            </button>
            <button
              id="scenario-defaults"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="defaults"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "defaults" && "bg-zinc-900 text-white",
                @scenario != "defaults" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Defaults
            </button>
            <button
              id="scenario-remote-uischema"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="remote-uischema"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "remote-uischema" && "bg-zinc-900 text-white",
                @scenario != "remote-uischema" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Remote UISchema
            </button>
            <button
              id="scenario-conditionals"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="conditionals"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "conditionals" && "bg-zinc-900 text-white",
                @scenario != "conditionals" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Conditionals
            </button>
            <button
              id="scenario-rule-not"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="rule-not"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "rule-not" && "bg-zinc-900 text-white",
                @scenario != "rule-not" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Rule NOT
            </button>
            <button
              id="scenario-widgets"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="widgets"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "widgets" && "bg-zinc-900 text-white",
                @scenario != "widgets" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Widgets
            </button>
            <button
              id="scenario-autocomplete"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="autocomplete"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "autocomplete" && "bg-zinc-900 text-white",
                @scenario != "autocomplete" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Autocomplete
            </button>
            <button
              id="scenario-list-detail"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="list-detail"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "list-detail" && "bg-zinc-900 text-white",
                @scenario != "list-detail" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              List With Detail
            </button>
            <button
              id="scenario-combinators"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="combinators"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "combinators" && "bg-zinc-900 text-white",
                @scenario != "combinators" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Combinators
            </button>
            <button
              id="scenario-interlinked"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="interlinked"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "interlinked" && "bg-zinc-900 text-white",
                @scenario != "interlinked" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Interlinked
            </button>
            <button
              id="scenario-categorization"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="categorization"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "categorization" && "bg-zinc-900 text-white",
                @scenario != "categorization" &&
                  "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Categories
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
              id="scenario-arrays-registered"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="arrays-registered"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "arrays-registered" && "bg-zinc-900 text-white",
                @scenario != "arrays-registered" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Arrays registered
            </button>
            <button
              id="scenario-arrays-generated"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="arrays-generated"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "arrays-generated" && "bg-zinc-900 text-white",
                @scenario != "arrays-generated" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Arrays generated
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
            <button
              id="scenario-custom"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="custom"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "custom" && "bg-zinc-900 text-white",
                @scenario != "custom" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Custom renderer
            </button>
            <button
              id="scenario-layouts"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="layouts"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "layouts" && "bg-zinc-900 text-white",
                @scenario != "layouts" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Layouts
            </button>
            <button
              id="scenario-arrays-multi"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="arrays-multi"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "arrays-multi" && "bg-zinc-900 text-white",
                @scenario != "arrays-multi" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Arrays multi
            </button>
            <button
              id="scenario-testers"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="testers"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "testers" && "bg-zinc-900 text-white",
                @scenario != "testers" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              Testers
            </button>
            <button
              id="scenario-oneof"
              type="button"
              phx-click="select_scenario"
              phx-value-scenario="oneof"
              class={[
                "rounded-full px-3 py-1 text-sm font-semibold transition",
                @scenario == "oneof" && "bg-zinc-900 text-white",
                @scenario != "oneof" && "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              ]}
            >
              oneOf titles
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
            <%= if @validation_mode == :validate_and_hide do %>
              <p id="demo-validation-note" class="text-xs text-zinc-600">
                Validator errors are hidden in the form UI.
              </p>
            <% end %>
          <% end %>

          <%= if @additional_errors != [] do %>
            <p id="demo-additional-errors-note" class="text-xs text-zinc-600">
              Additional errors injected ({length(@additional_errors)}).
            </p>
          <% end %>

          <%= if @scenario == "interlinked" and @form_group do %>
            <div id="demo-interlinked" class="grid gap-6 md:grid-cols-2">
              <div class="space-y-3 rounded-lg border border-zinc-200 p-4">
                <h3 class="text-xs font-semibold uppercase tracking-wide text-zinc-600">Form A</h3>
                <.form
                  for={@form_a}
                  id="demo-interlinked-form-a"
                  phx-change="form_group_change"
                  phx-value-form="a"
                >
                  <div
                    id={"demo-interlinked-wrapper-a-#{@interlinked_version_a || 0}"}
                    phx-update="replace"
                  >
                    <.json_forms
                      id="demo-interlinked-json-forms-a"
                      schema={@form_group_a.schema}
                      uischema={@form_group_a.uischema}
                      data={@form_group_a.data}
                      state={@form_group_a}
                      readonly={@readonly}
                      i18n={@i18n}
                      validation_mode={@validation_mode}
                      binding={:form_level}
                      renderers={@json_forms_renderers}
                      cells={@json_forms_cells}
                      opts={@json_forms_opts}
                      streams={assigns[:streams]}
                      wrap_form={false}
                    />
                  </div>
                </.form>
              </div>
              <div class="space-y-3 rounded-lg border border-zinc-200 p-4">
                <h3 class="text-xs font-semibold uppercase tracking-wide text-zinc-600">Form B</h3>
                <.form
                  for={@form_b}
                  id="demo-interlinked-form-b"
                  phx-change="form_group_change"
                  phx-value-form="b"
                >
                  <div
                    id={"demo-interlinked-wrapper-b-#{@interlinked_version_b || 0}"}
                    phx-update="replace"
                  >
                    <.json_forms
                      id="demo-interlinked-json-forms-b"
                      schema={@form_group_b.schema}
                      uischema={@form_group_b.uischema}
                      data={@form_group_b.data}
                      state={@form_group_b}
                      readonly={@readonly}
                      i18n={@i18n}
                      validation_mode={@validation_mode}
                      binding={:form_level}
                      renderers={@json_forms_renderers}
                      cells={@json_forms_cells}
                      opts={@json_forms_opts}
                      streams={assigns[:streams]}
                      wrap_form={false}
                    />
                  </div>
                </.form>
              </div>
            </div>
          <% else %>
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
                renderers={@json_forms_renderers}
                cells={@json_forms_cells}
                opts={@json_forms_opts}
                streams={assigns[:streams]}
                wrap_form={false}
              />

              <button
                id="demo-json-forms-submit"
                type="submit"
                tabindex="0"
                class="rounded-md bg-zinc-900 px-4 py-2 text-sm font-semibold text-white"
              >
                Submit
              </button>
            </.form>
          <% end %>
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
          <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-600">
            Errors (internal state)
          </h2>
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

        <%= if @scenario == "remote-uischema" do %>
          <div class="space-y-2">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-600">
              1. Original UISchema (with $ref)
            </h2>
            <pre class="rounded-lg bg-zinc-900 text-zinc-100 p-4 text-xs overflow-auto">
              {Jason.encode!(remote_uischema_uischema(), pretty: true)}
            </pre>
          </div>

          <div class="space-y-2">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-600">
              2. Remote Document (returned by uischema_ref_loader)
            </h2>
            <pre class="rounded-lg bg-zinc-900 text-zinc-100 p-4 text-xs overflow-auto">
              {Jason.encode!(remote_uischema_doc(), pretty: true)}
            </pre>
          </div>

          <div class="space-y-2">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-600">
              3. Resolved UISchema (after $ref resolution)
            </h2>
            <pre
              id="debug-uischema"
              class="rounded-lg bg-zinc-900 text-zinc-100 p-4 text-xs overflow-auto"
            >
              {Jason.encode!(@state.uischema, pretty: true)}
            </pre>
          </div>
        <% else %>
          <div class="space-y-2">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-zinc-600">UISchema</h2>
            <pre
              id="debug-uischema"
              class="rounded-lg bg-zinc-900 text-zinc-100 p-4 text-xs overflow-auto"
            >
              {Jason.encode!(@state.uischema, pretty: true)}
            </pre>
          </div>
        <% end %>
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
        # SHOW rule fields
        "show_flag" => %{"type" => "boolean", "title" => "Show field"},
        "show_note" => %{"type" => "string", "title" => "Shown note"},
        # HIDE rule fields
        "hide_flag" => %{"type" => "boolean", "title" => "Hide field"},
        "hide_note" => %{"type" => "string", "title" => "Hidden note"},
        # ENABLE rule fields
        "enable_flag" => %{"type" => "boolean", "title" => "Enable field"},
        "enable_note" => %{"type" => "string", "title" => "Enabled note"},
        # DISABLE rule fields
        "disable_flag" => %{"type" => "boolean", "title" => "Disable field"},
        "disable_note" => %{"type" => "string", "title" => "Disabled note"},
        # Composed conditions fields
        "and_flag" => %{"type" => "boolean", "title" => "Flag A"},
        "or_flag" => %{"type" => "boolean", "title" => "Flag B"},
        "and_note" => %{"type" => "string", "title" => "All conditions met"},
        "or_note" => %{"type" => "string", "title" => "Any condition met"},
        # failWhenUndefined fields
        "advanced_flag" => %{"type" => "boolean", "title" => "Advanced mode"},
        "advanced_note" => %{"type" => "string", "title" => "Advanced note"}
      }
    }
  end

  defp formats_schema do
    %{
      "type" => "object",
      "properties" => %{
        # Basic types
        "name" => %{
          "type" => "string",
          "title" => "Text"
        },
        "age" => %{
          "type" => "integer",
          "title" => "Integer"
        },
        "price" => %{
          "type" => "number",
          "title" => "Number"
        },
        "subscribed" => %{
          "type" => "boolean",
          "title" => "Boolean"
        },
        # String formats
        "email" => %{
          "type" => "string",
          "title" => "Email",
          "format" => "email"
        },
        "start_date" => %{
          "type" => "string",
          "title" => "Date",
          "format" => "date"
        },
        "start_time" => %{
          "type" => "string",
          "title" => "Time",
          "format" => "time"
        },
        "meeting" => %{
          "type" => "string",
          "title" => "DateTime",
          "format" => "date-time"
        },
        "notes" => %{
          "type" => "string",
          "title" => "Textarea"
        },
        # Enum types
        "status" => %{
          "type" => "string",
          "title" => "Enum (select)",
          "enum" => ["active", "paused", "closed"]
        },
        "status_radio" => %{
          "type" => "string",
          "title" => "Enum (radio)",
          "enum" => ["active", "paused", "closed"]
        },
        "priority" => %{
          "type" => "integer",
          "title" => "Integer enum",
          "enum" => [1, 2, 3]
        }
      }
    }
  end

  defp suggestions_schema do
    %{
      "type" => "object",
      "properties" => %{
        "assignee" => %{
          "type" => "string",
          "title" => "Assignee"
        },
        "estimate" => %{
          "type" => "number",
          "title" => "Estimate"
        },
        "status" => %{
          "type" => "string",
          "title" => "Status",
          "enum" => ["open", "blocked", "done"]
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
      "type" => "VerticalLayout",
      "elements" => [
        # Basic types
        %{"type" => "Label", "text" => "Basic types"},
        %{"type" => "Control", "scope" => "#/properties/name"},
        %{"type" => "Control", "scope" => "#/properties/age"},
        %{"type" => "Control", "scope" => "#/properties/price"},
        %{"type" => "Control", "scope" => "#/properties/subscribed"},
        # String formats
        %{"type" => "Label", "text" => "String formats"},
        %{"type" => "Control", "scope" => "#/properties/email"},
        %{"type" => "Control", "scope" => "#/properties/start_date"},
        %{"type" => "Control", "scope" => "#/properties/start_time"},
        %{"type" => "Control", "scope" => "#/properties/meeting"},
        %{
          "type" => "Control",
          "scope" => "#/properties/notes",
          "options" => %{"multi" => true}
        },
        # Enum types
        %{"type" => "Label", "text" => "Enum types"},
        %{"type" => "Control", "scope" => "#/properties/status"},
        %{
          "type" => "Control",
          "scope" => "#/properties/status_radio",
          "options" => %{"format" => "radio"}
        },
        %{"type" => "Control", "scope" => "#/properties/priority"}
      ]
    }
  end

  defp suggestions_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Control",
          "scope" => "#/properties/assignee",
          "options" => %{
            "placeholder" => "Type a name",
            "suggestion" => ["Ada", "Grace", "Linus"],
            "autocomplete" => "name"
          }
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/estimate",
          "options" => %{
            "placeholder" => "Hours",
            "suggestion" => [1, 2, 3, 5]
          }
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/status",
          "options" => %{
            "placeholder" => "Pick a status",
            "autocomplete" => true
          }
        }
      ]
    }
  end

  defp defaults_schema do
    %{
      "type" => "object",
      "properties" => %{
        "name" => %{
          "type" => "string",
          "title" => "Name",
          "description" => "default: \"Ada\"",
          "default" => "Ada"
        },
        "priority" => %{
          "type" => "integer",
          "title" => "Priority",
          "description" => "default: 2",
          "default" => 2
        },
        "status" => %{
          "type" => "string",
          "title" => "Status",
          "description" => "default: \"open\"",
          "enum" => ["open", "blocked", "done"],
          "default" => "open"
        }
      }
    }
  end

  defp defaults_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Label",
          "text" => "Initial data is empty, but fields are pre-filled from schema defaults"
        },
        %{"type" => "Control", "scope" => "#/properties/name"},
        %{"type" => "Control", "scope" => "#/properties/priority"},
        %{"type" => "Control", "scope" => "#/properties/status"}
      ]
    }
  end

  defp remote_uischema_uischema do
    %{
      "$ref" => "https://example.com/uischema.json#/definitions/remote"
    }
  end

  defp remote_uischema_doc do
    %{
      "$id" => "https://example.com/uischema.json",
      "definitions" => %{
        "remote" => %{
          "type" => "Group",
          "label" => "Loaded from Remote UISchema",
          "elements" => [
            %{"type" => "Control", "scope" => "#/properties/name"},
            %{"type" => "Control", "scope" => "#/properties/age"},
            %{"type" => "Control", "scope" => "#/properties/subscribed"}
          ]
        }
      }
    }
  end

  defp conditionals_schema do
    %{
      "type" => "object",
      "properties" => %{
        "mode" => %{
          "type" => "string",
          "title" => "Mode",
          "enum" => ["basic", "advanced"]
        },
        "summary" => %{
          "type" => "string",
          "title" => "Basic summary"
        },
        "details" => %{
          "type" => "string",
          "title" => "Advanced details"
        }
      },
      "if" => %{
        "properties" => %{
          "mode" => %{"const" => "advanced"}
        }
      },
      "then" => %{
        "required" => ["details"]
      }
    }
  end

  defp conditionals_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Label",
          "text" => "Select mode to conditionally show/require fields"
        },
        %{"type" => "Control", "scope" => "#/properties/mode"},
        %{
          "type" => "Control",
          "scope" => "#/properties/summary",
          "rule" => %{
            "effect" => "SHOW",
            "condition" => %{
              "scope" => "#/properties/mode",
              "schema" => %{"const" => "basic"}
            }
          }
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/details",
          "rule" => %{
            "effect" => "SHOW",
            "condition" => %{
              "scope" => "#/properties/mode",
              "schema" => %{"const" => "advanced"}
            }
          }
        }
      ]
    }
  end

  defp rule_not_schema do
    %{
      "type" => "object",
      "properties" => %{
        "flag" => %{"type" => "boolean", "title" => "Flag"},
        "note" => %{"type" => "string", "title" => "Note"}
      }
    }
  end

  defp rule_not_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{"type" => "Control", "scope" => "#/properties/flag"},
        %{
          "type" => "Control",
          "scope" => "#/properties/note",
          "rule" => %{
            "effect" => "SHOW",
            "condition" => %{
              "type" => "NOT",
              "condition" => %{
                "scope" => "#/properties/flag",
                "schema" => %{"const" => true}
              }
            }
          }
        }
      ]
    }
  end

  defp widgets_schema do
    %{
      "type" => "object",
      "properties" => %{
        "enabled" => %{
          "type" => "boolean",
          "title" => "Enabled"
        },
        "volume" => %{
          "type" => "number",
          "title" => "Volume",
          "minimum" => 0,
          "maximum" => 10,
          "multipleOf" => 0.5
        }
      }
    }
  end

  defp widgets_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Control",
          "scope" => "#/properties/enabled",
          "options" => %{
            "toggle" => true
          }
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/volume",
          "options" => %{
            "slider" => true
          }
        }
      ]
    }
  end

  defp autocomplete_schema do
    %{
      "type" => "object",
      "properties" => %{
        "assignee" => %{
          "type" => "string",
          "title" => "Assignee",
          "enum" => ["Ada", "Grace", "Linus", "Joan"]
        }
      }
    }
  end

  defp autocomplete_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Control",
          "scope" => "#/properties/assignee",
          "options" => %{
            "autocomplete" => true,
            "placeholder" => "Start typing"
          }
        }
      ]
    }
  end

  defp list_detail_schema do
    %{
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
    }
  end

  defp list_detail_uischema do
    %{
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
                %{
                  "type" => "Control",
                  "scope" => "#/properties/lastname",
                  "label" => "Last Name"
                }
              ]
            },
            %{"type" => "Control", "scope" => "#/properties/age", "label" => "Age"},
            %{"type" => "Control", "scope" => "#/properties/email", "label" => "Email"}
          ]
        },
        "elementLabelProp" => "firstname",
        "defaultOpenIndex" => 0
      }
    }
  end

  defp combinators_schema do
    # JSON Schema combinators demo
    # See: https://jsonforms.io/docs/multiple-choice
    %{
      "type" => "object",
      "properties" => %{
        # oneOf single-select - dropdown with custom labels
        "priority" => %{
          "title" => "Priority (oneOf)",
          "type" => "string",
          "oneOf" => [
            %{"const" => "low", "title" => "Low"},
            %{"const" => "medium", "title" => "Medium"},
            %{"const" => "high", "title" => "High"}
          ]
        },
        # oneOf multi-select - array with uniqueItems
        "tags" => %{
          "title" => "Tags (oneOf multi)",
          "type" => "array",
          "uniqueItems" => true,
          "items" => %{
            "oneOf" => [
              %{"const" => "frontend", "title" => "Frontend"},
              %{"const" => "backend", "title" => "Backend"},
              %{"const" => "devops", "title" => "DevOps"}
            ]
          }
        },
        # enum single-select - dropdown with raw values
        "status" => %{
          "title" => "Status (enum)",
          "type" => "string",
          "enum" => ["draft", "published", "archived"]
        },
        # enum multi-select - array with uniqueItems
        "categories" => %{
          "title" => "Categories (enum multi)",
          "type" => "array",
          "uniqueItems" => true,
          "items" => %{
            "type" => "string",
            "enum" => ["tech", "business", "design"]
          }
        },
        # allOf merges schemas
        "person" => %{
          "title" => "Person (allOf)",
          "allOf" => [
            %{
              "type" => "object",
              "properties" => %{
                "name" => %{"type" => "string", "title" => "Name"}
              }
            },
            %{
              "type" => "object",
              "properties" => %{
                "age" => %{"type" => "integer", "title" => "Age"}
              }
            }
          ]
        }
      }
    }
  end

  defp combinators_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Label",
          "text" => "oneOf: Dropdown with custom labels (value=low, label=Low)"
        },
        %{"type" => "Control", "scope" => "#/properties/priority"},
        %{
          "type" => "Label",
          "text" => "oneOf + array: Multi-select with custom labels"
        },
        %{"type" => "Control", "scope" => "#/properties/tags"},
        %{
          "type" => "Label",
          "text" => "enum: Dropdown with raw values"
        },
        %{"type" => "Control", "scope" => "#/properties/status"},
        %{
          "type" => "Label",
          "text" => "enum + array: Multi-select with raw values"
        },
        %{"type" => "Control", "scope" => "#/properties/categories"},
        %{
          "type" => "Label",
          "text" => "allOf: Merges schemas (Name from schema1 + Age from schema2)"
        },
        %{"type" => "Control", "scope" => "#/properties/person"}
      ]
    }
  end

  defp interlinked_schema do
    %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string", "title" => "Name"},
        "status" => %{
          "type" => "string",
          "title" => "Status",
          "enum" => ["active", "paused", "closed"]
        },
        "note" => %{"type" => "string", "title" => "Note"}
      }
    }
  end

  defp interlinked_uischema_a do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{"type" => "Control", "scope" => "#/properties/name"},
        %{"type" => "Control", "scope" => "#/properties/status"}
      ]
    }
  end

  defp interlinked_uischema_b do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{"type" => "Control", "scope" => "#/properties/status"},
        %{"type" => "Control", "scope" => "#/properties/note"}
      ]
    }
  end

  defp categorization_schema do
    %{
      "type" => "object",
      "properties" => %{
        "person" => %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string", "title" => "Name"},
            "title" => %{"type" => "string", "title" => "Title"},
            "subscribed" => %{"type" => "boolean", "title" => "Subscribed"}
          }
        },
        "project" => %{
          "type" => "object",
          "properties" => %{
            "status" => %{
              "type" => "string",
              "title" => "Status",
              "enum" => ["active", "paused", "complete"]
            },
            "priority" => %{
              "type" => "number",
              "title" => "Priority",
              "enum" => [1, 2, 3]
            },
            "start_date" => %{"type" => "string", "format" => "date"},
            "meeting" => %{"type" => "string", "format" => "date-time"}
          }
        },
        "notes" => %{
          "type" => "object",
          "properties" => %{
            "details" => %{"type" => "string", "title" => "Notes"}
          }
        }
      }
    }
  end

  defp categorization_uischema do
    %{
      "type" => "Categorization",
      "options" => %{"defaultCategory" => 0},
      "elements" => [
        %{
          "type" => "Category",
          "label" => "Profile",
          "elements" => [
            %{"type" => "Control", "scope" => "#/properties/person/properties/name"},
            %{"type" => "Control", "scope" => "#/properties/person/properties/title"},
            %{"type" => "Control", "scope" => "#/properties/person/properties/subscribed"}
          ]
        },
        %{
          "type" => "Category",
          "label" => "Project",
          "elements" => [
            %{
              "type" => "Control",
              "scope" => "#/properties/project/properties/status",
              "options" => %{"format" => "radio"}
            },
            %{"type" => "Control", "scope" => "#/properties/project/properties/priority"},
            %{"type" => "Control", "scope" => "#/properties/project/properties/start_date"},
            %{"type" => "Control", "scope" => "#/properties/project/properties/meeting"}
          ]
        },
        %{
          "type" => "Category",
          "label" => "Notes",
          "elements" => [
            %{
              "type" => "Control",
              "scope" => "#/properties/notes/properties/details",
              "options" => %{"multi" => true}
            }
          ]
        }
      ]
    }
  end

  defp arrays_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Label",
          "text" => "detail: DEFAULT - auto-generates controls for all properties (Title + Done)"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/tasks",
          "options" => %{"showSortButtons" => true, "elementLabelProp" => "title"}
        }
      ]
    }
  end

  defp arrays_multi_schema do
    %{
      "type" => "object",
      "properties" => %{
        "tags" => %{
          "type" => "array",
          "items" => %{
            "type" => "string",
            "enum" => ["alpha", "beta", "gamma", "delta"]
          }
        }
      }
    }
  end

  defp arrays_multi_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Control",
          "scope" => "#/properties/tags"
        }
      ]
    }
  end

  defp layouts_schema do
    %{
      "type" => "object",
      "properties" => %{
        "first_name" => %{"type" => "string", "title" => "First name"},
        "last_name" => %{"type" => "string", "title" => "Last name"},
        "role" => %{"type" => "string", "title" => "Role"},
        "team" => %{"type" => "string", "title" => "Team"}
      }
    }
  end

  defp layouts_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "HorizontalLayout",
          "elements" => [
            %{"type" => "Control", "scope" => "#/properties/first_name"},
            %{"type" => "Control", "scope" => "#/properties/last_name"}
          ]
        },
        %{
          "type" => "Group",
          "label" => "Spotlight",
          "options" => %{"variant" => "spotlight"},
          "elements" => [
            %{"type" => "Control", "scope" => "#/properties/role"},
            %{"type" => "Control", "scope" => "#/properties/team"}
          ]
        }
      ]
    }
  end

  defp testers_schema do
    %{
      "type" => "object",
      "properties" => %{
        "status" => %{
          "type" => "string",
          "title" => "Status",
          "enum" => ["active", "paused"]
        },
        "priority" => %{"type" => "number", "title" => "Priority", "enum" => [1, 2, 3]},
        "ignore" => %{"type" => "string", "title" => "Ignore"}
      }
    }
  end

  defp testers_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Label",
          "text" => "Testers: composable predicates for renderer matching"
        },
        %{
          "type" => "Label",
          "text" =>
            "TesterControl matches: all_of([ui_type_is(Control), any_of([scope_ends_with(status), scope_ends_with(priority)]), not_of(scope_ends_with(ignore))])"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/status",
          "label" => "Status (highlighted - matches scope_ends_with)"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/priority",
          "label" => "Priority (highlighted - matches scope_ends_with)"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/ignore",
          "label" => "Ignore (NOT highlighted - excluded by not_of)"
        }
      ]
    }
  end

  defp i18n_schema do
    %{
      "type" => "object",
      "properties" => %{
        "status" => %{
          "type" => "string",
          "enum" => ["active", "paused", "closed"]
        },
        "priority" => %{
          "type" => "integer",
          "enum" => [1, 2, 3]
        },
        "start_date" => %{
          "type" => "string",
          "format" => "date"
        },
        "meeting" => %{
          "type" => "string",
          "format" => "date-time"
        },
        "notes" => %{
          "type" => "string"
        }
      }
    }
  end

  defp i18n_uischema do
    %{
      "type" => "Group",
      "label" => "project",
      "elements" => [
        %{
          "type" => "Control",
          "scope" => "#/properties/status",
          "options" => %{"format" => "radio"}
        },
        %{"type" => "Control", "scope" => "#/properties/priority"},
        %{"type" => "Label", "text" => "project.schedule"},
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

  defp oneof_schema do
    %{
      "type" => "object",
      "properties" => %{
        "tier" => %{
          "type" => "string",
          "oneOf" => [
            %{"const" => "starter", "title" => "Starter"},
            %{"const" => "pro", "title" => "Pro"},
            %{"const" => "enterprise", "title" => "Enterprise"}
          ]
        }
      }
    }
  end

  defp oneof_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{"type" => "Control", "scope" => "#/properties/tier"}
      ]
    }
  end

  defp custom_schema do
    %{
      "type" => "object",
      "required" => ["message"],
      "properties" => %{
        "message" => %{"type" => "string", "title" => "Message"},
        "note" => %{"type" => "string", "title" => "Note"}
      }
    }
  end

  defp custom_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Label",
          "text" => "Custom cell (ShoutInput): orange border + uppercase preview"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/message",
          "options" => %{"format" => "shout"}
        },
        %{
          "type" => "Label",
          "text" => "Custom renderer (CalloutControl): gray callout-style wrapper"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/note",
          "options" => %{"format" => "callout"}
        }
      ]
    }
  end

  defp arrays_registered_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Label",
          "text" => "detail: REGISTERED - item layout from registry (only shows Title, not Done)"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/tasks",
          "options" => %{
            "detail" => "REGISTERED",
            "detailKey" => "task_detail",
            "showSortButtons" => true,
            "elementLabelProp" => "title"
          }
        }
      ]
    }
  end

  defp arrays_generated_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Label",
          "text" => "detail: GENERATED - explicitly auto-generate controls from schema properties"
        },
        %{
          "type" => "Label",
          "text" => "Same result as DEFAULT, but explicit. Shows all properties: Title + Done"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/tasks",
          "options" => %{
            "detail" => "GENERATED",
            "showSortButtons" => true,
            "elementLabelProp" => "title"
          }
        }
      ]
    }
  end

  defp readonly_schema do
    %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string", "title" => "Name"},
        "schema_readonly" => %{
          "type" => "string",
          "title" => "Schema readOnly",
          "readOnly" => true
        },
        "uischema_readonly" => %{"type" => "string", "title" => "UISchema readOnly"}
      }
    }
  end

  defp readonly_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Label",
          "text" => "Toggle affects only Name (others have explicit readOnly)"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/name",
          "label" => "Name (component readonly prop)"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/schema_readonly",
          "label" => "Schema readOnly: true (always readonly)"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/uischema_readonly",
          "label" => "UISchema options.readOnly: true (always readonly)",
          "options" => %{"readOnly" => true}
        }
      ]
    }
  end

  defp readonly_precedence_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Label",
          "text" => "Component readonly=false, but schema/uischema readOnly takes precedence"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/name",
          "label" => "Name (editable - no explicit readOnly)"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/schema_readonly",
          "label" => "Schema readOnly: true (precedence over component)"
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/uischema_readonly",
          "label" => "UISchema readOnly: true (precedence over component)",
          "options" => %{"readOnly" => true}
        }
      ]
    }
  end

  defp rules_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        # SHOW rule - field appears when condition is true
        %{"type" => "Label", "text" => "SHOW rule (field appears when checked)"},
        %{"type" => "Control", "scope" => "#/properties/show_flag"},
        %{
          "type" => "Control",
          "scope" => "#/properties/show_note",
          "rule" => %{
            "effect" => "SHOW",
            "condition" => %{
              "scope" => "#/properties/show_flag",
              "schema" => %{"const" => true}
            }
          }
        },
        # HIDE rule - field disappears when condition is true
        %{"type" => "Label", "text" => "HIDE rule (field disappears when checked)"},
        %{"type" => "Control", "scope" => "#/properties/hide_flag"},
        %{
          "type" => "Control",
          "scope" => "#/properties/hide_note",
          "rule" => %{
            "effect" => "HIDE",
            "condition" => %{
              "scope" => "#/properties/hide_flag",
              "schema" => %{"const" => true}
            }
          }
        },
        # ENABLE rule - field becomes editable when condition is true
        %{"type" => "Label", "text" => "ENABLE rule (field becomes editable when checked)"},
        %{"type" => "Control", "scope" => "#/properties/enable_flag"},
        %{
          "type" => "Control",
          "scope" => "#/properties/enable_note",
          "rule" => %{
            "effect" => "ENABLE",
            "condition" => %{
              "scope" => "#/properties/enable_flag",
              "schema" => %{"const" => true}
            }
          }
        },
        # DISABLE rule - field becomes read-only when condition is true
        %{"type" => "Label", "text" => "DISABLE rule (field becomes read-only when checked)"},
        %{"type" => "Control", "scope" => "#/properties/disable_flag"},
        %{
          "type" => "Control",
          "scope" => "#/properties/disable_note",
          "rule" => %{
            "effect" => "DISABLE",
            "condition" => %{
              "scope" => "#/properties/disable_flag",
              "schema" => %{"const" => true}
            }
          }
        },
        # Composed conditions (AND/OR)
        %{"type" => "Label", "text" => "Composed conditions (AND/OR)"},
        %{"type" => "Control", "scope" => "#/properties/and_flag"},
        %{"type" => "Control", "scope" => "#/properties/or_flag"},
        %{
          "type" => "Control",
          "scope" => "#/properties/and_note",
          "rule" => %{
            "effect" => "SHOW",
            "condition" => %{
              "type" => "AND",
              "conditions" => [
                %{
                  "scope" => "#/properties/and_flag",
                  "schema" => %{"const" => true}
                },
                %{
                  "scope" => "#/properties/or_flag",
                  "schema" => %{"const" => true}
                }
              ]
            }
          }
        },
        %{
          "type" => "Control",
          "scope" => "#/properties/or_note",
          "rule" => %{
            "effect" => "SHOW",
            "condition" => %{
              "type" => "OR",
              "conditions" => [
                %{
                  "scope" => "#/properties/and_flag",
                  "schema" => %{"const" => true}
                },
                %{
                  "scope" => "#/properties/or_flag",
                  "schema" => %{"const" => true}
                }
              ]
            }
          }
        },
        # failWhenUndefined - rule fails (hides field) when referenced value is undefined
        %{
          "type" => "Label",
          "text" => "failWhenUndefined (field hidden until flag has a value)"
        },
        %{"type" => "Control", "scope" => "#/properties/advanced_flag"},
        %{
          "type" => "Control",
          "scope" => "#/properties/advanced_note",
          "rule" => %{
            "effect" => "SHOW",
            "failWhenUndefined" => true,
            "condition" => %{
              "scope" => "#/properties/advanced_flag",
              "schema" => %{"const" => true}
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
      data: %{
        "show_flag" => false,
        "show_note" => "I appear when checked",
        "hide_flag" => false,
        "hide_note" => "I disappear when checked",
        "enable_flag" => false,
        "enable_note" => "I become editable when checked",
        "disable_flag" => false,
        "disable_note" => "I become read-only when checked",
        "and_flag" => false,
        "or_flag" => false,
        "and_note" => "Both flags enabled (AND)",
        "or_note" => "Either flag enabled (OR)"
      }
    })
  end

  defp scenario_config("formats") do
    base_config(%{
      schema: formats_schema(),
      uischema: formats_uischema(),
      data: %{
        "name" => "Ada",
        "age" => 32,
        "price" => 19.99,
        "subscribed" => true,
        "email" => "ada@example.com",
        "start_date" => "2025-01-30",
        "start_time" => "09:30",
        "meeting" => "2025-01-30T10:00",
        "notes" => "Meeting notes here",
        "status" => "active",
        "status_radio" => "active",
        "priority" => 1
      }
    })
  end

  defp scenario_config("suggestions") do
    base_config(%{
      schema: suggestions_schema(),
      uischema: suggestions_uischema(),
      data: %{
        "assignee" => "Ada",
        "estimate" => 2,
        "status" => "open"
      }
    })
  end

  defp scenario_config("defaults") do
    base_config(%{
      schema: defaults_schema(),
      uischema: defaults_uischema(),
      data: %{},
      json_forms_opts: %{
        apply_defaults: true
      }
    })
  end

  defp scenario_config("remote-uischema") do
    base_config(%{
      schema: demo_schema(),
      uischema: remote_uischema_uischema(),
      data: %{"name" => "Ada", "age" => 32, "subscribed" => true},
      json_forms_opts: %{
        uischema_ref_loader: &demo_uischema_loader/2
      }
    })
  end

  defp scenario_config("conditionals") do
    base_config(%{
      schema: conditionals_schema(),
      uischema: conditionals_uischema(),
      data: %{"mode" => "basic", "summary" => "Quick overview"}
    })
  end

  defp scenario_config("rule-not") do
    base_config(%{
      schema: rule_not_schema(),
      uischema: rule_not_uischema(),
      data: %{"flag" => false, "note" => "Visible when flag is false"}
    })
  end

  defp scenario_config("widgets") do
    base_config(%{
      schema: widgets_schema(),
      uischema: widgets_uischema(),
      data: %{"enabled" => true, "volume" => 4.5}
    })
  end

  defp scenario_config("autocomplete") do
    base_config(%{
      schema: autocomplete_schema(),
      uischema: autocomplete_uischema(),
      data: %{"assignee" => "Ada"}
    })
  end

  defp scenario_config("list-detail") do
    base_config(%{
      schema: list_detail_schema(),
      uischema: list_detail_uischema(),
      data: %{
        "users" => [
          %{
            "firstname" => "Ada",
            "lastname" => "Lovelace",
            "age" => 36,
            "email" => "ada@lovelace.dev"
          },
          %{
            "firstname" => "Grace",
            "lastname" => "Hopper",
            "age" => 45,
            "email" => "grace@hopper.dev"
          }
        ]
      }
    })
  end

  defp scenario_config("combinators") do
    base_config(%{
      schema: combinators_schema(),
      uischema: combinators_uischema(),
      data: %{
        "priority" => "medium",
        "tags" => ["frontend", "backend"],
        "status" => "published",
        "categories" => ["tech", "design"],
        "person" => %{"name" => "Ada", "age" => 36}
      }
    })
  end

  defp scenario_config("interlinked") do
    schema = interlinked_schema()
    data = %{"name" => "Ada", "status" => "active", "note" => "Synced note"}

    {:ok, group} =
      FormGroup.init([
        %{id: :a, schema: schema, uischema: interlinked_uischema_a(), data: data},
        %{id: :b, schema: schema, uischema: interlinked_uischema_b(), data: data}
      ])

    base_config(%{
      schema: schema,
      uischema: interlinked_uischema_a(),
      data: group.data,
      form_group: group,
      form_group_a: FormGroup.state(group, :a),
      form_group_b: FormGroup.state(group, :b)
    })
  end

  defp scenario_config("categorization") do
    base_config(%{
      schema: categorization_schema(),
      uischema: categorization_uischema(),
      data: %{
        "person" => %{"name" => "Ada", "title" => "Engineer", "subscribed" => true},
        "project" => %{
          "status" => "active",
          "priority" => 2,
          "start_date" => "2025-02-01",
          "meeting" => "2025-02-01T09:00"
        },
        "notes" => %{"details" => "Keep tabs on deliverables"}
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

  defp scenario_config("arrays-registered") do
    base_config(%{
      schema: arrays_schema(),
      uischema: arrays_registered_uischema(),
      data: %{
        "tasks" => [
          %{"title" => "Plan", "done" => false},
          %{"title" => "Build", "done" => true}
        ]
      },
      json_forms_opts: %{
        detail_registry: %{
          "task_detail" => %{
            "type" => "VerticalLayout",
            "elements" => [
              %{"type" => "Control", "scope" => "#/properties/title"}
            ]
          }
        }
      }
    })
  end

  defp scenario_config("arrays-generated") do
    base_config(%{
      schema: arrays_schema(),
      uischema: arrays_generated_uischema(),
      data: %{
        "tasks" => [
          %{"title" => "Plan", "done" => false},
          %{"title" => "Build", "done" => true}
        ]
      }
    })
  end

  defp scenario_config("custom") do
    base_config(%{
      schema: custom_schema(),
      uischema: custom_uischema(),
      data: %{"message" => "Hello", "note" => "Keep it simple"},
      json_forms_cells: [JsonFormsLvDemoWeb.CustomCells.ShoutInput],
      json_forms_renderers: [JsonFormsLvDemoWeb.CustomRenderers.CalloutControl]
    })
  end

  defp scenario_config("layouts") do
    base_config(%{
      schema: layouts_schema(),
      uischema: layouts_uischema(),
      data: %{
        "first_name" => "Ada",
        "last_name" => "Lovelace",
        "role" => "Engineer",
        "team" => "Core"
      },
      json_forms_renderers: [JsonFormsLvDemoWeb.CustomRenderers.SpotlightGroup]
    })
  end

  defp scenario_config("arrays-multi") do
    base_config(%{
      schema: arrays_multi_schema(),
      uischema: arrays_multi_uischema(),
      data: %{"tags" => ["alpha", "gamma"]}
    })
  end

  defp scenario_config("testers") do
    base_config(%{
      schema: testers_schema(),
      uischema: testers_uischema(),
      data: %{"status" => "active", "priority" => 2, "ignore" => "skip"},
      json_forms_renderers: [JsonFormsLvDemoWeb.CustomRenderers.TesterControl]
    })
  end

  defp scenario_config("oneof") do
    base_config(%{
      schema: oneof_schema(),
      uischema: oneof_uischema(),
      data: %{"tier" => "pro"}
    })
  end

  defp scenario_config("i18n") do
    base_config(%{
      schema: i18n_schema(),
      uischema: i18n_uischema(),
      data: %{
        "status" => "active",
        "priority" => 2,
        "start_date" => "2025-01-30",
        "meeting" => "2025-01-30T10:00",
        "notes" => "Meeting notes"
      },
      locale: "en",
      i18n: demo_i18n("en")
    })
  end

  defp scenario_config("readonly") do
    base_config(%{
      schema: readonly_schema(),
      uischema: readonly_uischema(),
      data: %{
        "name" => "Editable when toggle off",
        "schema_readonly" => "Always readonly (schema)",
        "uischema_readonly" => "Always readonly (uischema)"
      },
      readonly: true
    })
  end

  defp scenario_config("readonly-precedence") do
    base_config(%{
      schema: readonly_schema(),
      uischema: readonly_precedence_uischema(),
      data: %{
        "name" => "Editable (toggle is off)",
        "schema_readonly" => "Still readonly (schema takes precedence)",
        "uischema_readonly" => "Still readonly (uischema takes precedence)"
      },
      readonly: false
    })
  end

  defp scenario_config("validation") do
    base_config(%{
      schema: demo_schema(),
      uischema: validation_uischema(),
      data: %{"name" => "", "age" => 32, "subscribed" => true},
      validation_mode: :validate_and_hide,
      additional_errors: [
        %{
          "instancePath" => "/name",
          "message" => "Name already reserved",
          "keyword" => "external"
        }
      ]
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

  defp validation_uischema do
    %{
      "type" => "VerticalLayout",
      "elements" => [
        %{
          "type" => "Label",
          "text" => "Validation modes: Show (display errors), Hide (validate silently), Off"
        },
        %{
          "type" => "Label",
          "text" => "Additional error injected: 'Name already reserved' (simulates server-side)"
        },
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
        additional_errors: [],
        form_group: nil,
        form_group_a: nil,
        form_group_b: nil,
        json_forms_opts: %{},
        json_forms_cells: [],
        json_forms_renderers: []
      },
      overrides
    )
  end

  defp maybe_set_additional_errors(state, errors) when is_list(errors) and errors != [] do
    Engine.set_additional_errors(state, errors)
  end

  defp maybe_set_additional_errors(state, _errors), do: {:ok, state}

  defp form_group_id("a"), do: :a
  defp form_group_id("b"), do: :b
  defp form_group_id(_), do: :a

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
      "project.schedule" => "Horario",
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

  defp demo_translations("en") do
    %{
      "project.schedule" => "Schedule",
      "priority.1" => "Low",
      "priority.2" => "Medium",
      "priority.3" => "High"
    }
  end

  defp demo_translations(_locale), do: %{}

  defp demo_uischema_loader("https://example.com/uischema.json", _opts) do
    {:ok, remote_uischema_doc()}
  end

  defp demo_uischema_loader(_uri, _opts), do: {:error, :not_found}

  defp maybe_sync_array_streams(socket, old_state, new_state, config \\ nil) do
    opts =
      cond do
        is_map(config) -> Map.get(config, :json_forms_opts, %{})
        is_map(socket.assigns.json_forms_opts) -> socket.assigns.json_forms_opts
        true -> %{}
      end

    opts = Map.put_new(opts, :form_id, "demo-json-forms")

    StreamSync.sync(socket, old_state, new_state, opts)
  end
end
