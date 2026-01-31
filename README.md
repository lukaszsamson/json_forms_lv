# JsonFormsLV

Server-side JSON Forms 3.x renderer for Phoenix LiveView.

See `SPEC_V1.md` for the v1 scope, architecture, and implementation plan.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `json_forms_lv` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:json_forms_lv, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/json_forms_lv>.

## Custom renderers and cells (demo)

See the demo app for concrete examples of custom renderers and cells:

- Custom cell: `demo/lib/json_forms_lv_demo_web/custom_cells/shout_input.ex`
- Custom control renderer: `demo/lib/json_forms_lv_demo_web/custom_renderers/callout_control.ex`
- Scenario wiring: `demo/lib/json_forms_lv_demo_web/live/demo_live.ex`
- LiveView test coverage: `demo/test/json_forms_lv_demo_web/live/demo_live_test.exs`

### Tester helper snippet

```elixir
alias JsonFormsLV.Testers

def tester(uischema, schema, ctx) do
  Testers.rank_with(25, Testers.all_of([
    Testers.ui_type_is("Control"),
    Testers.schema_type_is("string"),
    Testers.has_option("format", "custom")
  ])).(uischema, schema, ctx)
end
```

### Custom renderer registration

The component accepts `renderers`, `control_renderers`, and `layout_renderers`.
Any list passed via `renderers` is applied to both control and layout categories.

## Rendering components

Use the function component when you manage `JsonFormsLV.State` in your LiveView:

```elixir
<.json_forms
  id="profile-form"
  schema={@schema}
  uischema={@uischema}
  data={@data}
  state={@state}
  wrap_form={false}
/>
```

When `state` is omitted, the function component renders without running `Engine.init/4`
(no validation, defaults, or rule evaluation). Prefer passing a precomputed state or use
the LiveComponent for self-contained mode.

When `state` is provided, the function component treats it as the source of truth.
Props like `validation_mode` or `additional_errors` are ignored unless they are already
reflected in the `state`.

For a self-contained integration, use the LiveComponent:

```elixir
<.live_component
  module={JsonFormsLV.Phoenix.LiveComponent}
  id="profile-form"
  schema={@schema}
  uischema={@uischema}
  data={@data}
  opts={@json_forms_opts}
  notify={self()}
/>
```

### Form-level event helpers

Use `JsonFormsLV.Phoenix.Events` to extract form-level bindings from LiveView params:

```elixir
case JsonFormsLV.Phoenix.Events.extract_form_change(params) do
  {:ok, %{path: path, value: value, meta: meta}} ->
    Engine.update_data(state, path, value, meta)

  {:error, _reason} ->
    {:error, :invalid_params}
end
```

### Log tester errors

Enable logging for custom tester exceptions:

```elixir
config :json_forms_lv, log_tester_errors: true
```

### Telemetry

The library emits basic Telemetry events (all include `%{duration: t}`):

- `[:json_forms_lv, :init]` — metadata: `validation_mode`
- `[:json_forms_lv, :update_data]` — metadata: `path`, `result`
- `[:json_forms_lv, :validate]` — metadata: `error_count`, `rules_total`, `rules_evaluated`, `rules_incremental`, `rules_changed_paths`
- `[:json_forms_lv, :dispatch]` — metadata: `kind`, `renderer`, `uischema_type`, `schema_type`, `path`

### Validation timing

Control when validation runs by setting `opts[:validate_on]` (default: `:change`).

- `:change` — validate on every change
- `:blur` — validate on blur and submit
- `:submit` — validate only on submit

### Defaults

Enable `opts[:apply_defaults]` to apply JSON Schema defaults when initializing data.

### Data size limits

`opts[:max_data_bytes]` defaults to 1,000,000 bytes. For large payloads or to avoid
size checks on every change, set it to `:infinity`.

### Path format

JsonFormsLV uses dot-delimited data paths internally (for example: `"profile.name"`).
Property names containing dots are not supported.

### UISchema defaults

When `uischema` is `nil`, `Engine.init/4` generates a default `VerticalLayout` with
`Control` elements for each top-level schema property.

### UISchema $ref resolution

`Engine.init/4` resolves `$ref` pointers in the UISchema. Local (`#...`) refs resolve
within the same document. Remote refs require a loader function via
`opts[:uischema_ref_loader]` (called with the URI and opts) and otherwise return an error.
Override the resolver with `opts[:uischema_resolver]` when needed.

### Format support

`format: "time"` renders a native `<input type="time">` control.

### Input options

- `placeholder`: placeholder text for string/number/date/time inputs (and empty option label for enum selects).
- `suggestion`: list of suggestion values to render a `<datalist>` for string/number inputs.
- `autocomplete`: when `true` for enum controls, renders a text input with datalist options;
  for string/number inputs it sets the HTML `autocomplete` attribute (boolean or string).
- Autocomplete renderer: enum controls with `options.autocomplete` use the autocomplete cell.
- `toggle`: render booleans as a switch-style checkbox.
- `slider`: render numbers as a range input using schema `minimum`/`maximum`/`multipleOf`.
- ListWithDetail renderer: use `uischema.type = "ListWithDetail"` for array detail lists.
- Combinator control: `oneOf`/`anyOf`/`allOf` schemas render a selector and detail sections.

### Combinator selection

`CombinatorControl` emits `jf:select_combinator` with `path` + `selection`. The LiveComponent
handles this automatically; custom hosts can call `Engine.set_combinator/3` to persist selection.

### writeOnly handling

Schema properties marked with `"writeOnly": true` are cleared from rendered inputs after submission
to avoid echoing sensitive values back into the DOM.
- Date/time picker options: `dateFormat`, `dateSaveFormat`, `timeFormat`, `timeSaveFormat`,
  `dateTimeFormat`, `dateTimeSaveFormat`, `ampm`, `views`, `clearLabel`, `cancelLabel`, `okLabel`.
  These are exposed as `data-jf-*` attributes on native inputs for custom picker hooks.

### Categorization tab state

When using the function component, you can persist the active tab by storing a
`categorization_state` map in your LiveView assigns:

```elixir
# In mount/handle_event
@categorization_state = %{"Categorization@/" => 1}

# In render
<.json_forms
  id="profile-form"
  schema={@schema}
  uischema={@uischema}
  data={@data}
  state={@state}
  opts={%{categorization_state: @categorization_state}}
/>
```
