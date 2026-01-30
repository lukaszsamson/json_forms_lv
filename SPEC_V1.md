# JSON Forms 3.x Renderer for Phoenix LiveView (Spec V1)

This document specifies a Phoenix LiveView renderer library that implements the JSON Forms "contract" (JSON Schema + UISchema + data) server-side.

The goal is to let Phoenix LiveView applications render and interact with JSON Forms-driven forms without running JSON Forms in the browser. LiveView diffs/streams provide UI updates, while the server maintains JSON Forms-like state (data, validation, rules, renderer selection).

Status: draft, v1 scope (MVP + clear extension points).

---

## 1) Compatibility and terminology

### JSON Forms 3.x contract (inputs)

- `schema`: JSON Schema (object) describing the data instance.
- `uischema`: JSON Forms UISchema (object) describing layout/controls.
- `data`: JSON instance (map/list/scalar).

### JSON Forms 3.x semantics we mirror

- **Scopes**: `Control.scope` points into the *schema* using a JSON Pointer (e.g. `#/properties/name`), which implies a binding to a data location.
- **Validation modes**: JSON Forms core defines `ValidationMode` as `"ValidateAndShow" | "ValidateAndHide" | "NoValidation"`.
- **Rules**: UISchema elements can have `rule: %{effect, condition}`; `condition` validates the value found at `condition.scope` against `condition.schema`. `failWhenUndefined` optionally turns an undefined scope into a failing condition.
- **External errors**: `additionalErrors` accept AJV-like objects (`instancePath`, `message`, `keyword`, `schemaPath`, `params`).
- **Renderer selection**: JSON Forms uses "tester" functions returning a rank. Highest rank wins. ("Not applicable" means ignore.)
- **i18n**: JSON Forms accepts `i18n: %{locale, translate}` and UISchema elements may carry an `i18n` key.
- **readonly**: JSON Forms can operate in a global readonly mode (all controls disabled).

### LiveView terms (this library)

- **Controlled integration**: parent LiveView owns state and handles events; the renderer emits events.
- **Self-contained integration**: a LiveComponent owns state; still offers hooks to notify parent.

---

## 2) Goals and non-goals

### Goals (v1)

1. Render UISchema -> HEEx using Phoenix function components (with optional LiveComponents for heavy subtrees).
2. Provide JSON Forms-like data binding: `scope` -> "data path" and updates at a path.
3. Provide server-side JSON Schema validation with JSON Forms-like modes and support for `additionalErrors`.
4. Implement UISchema rules (HIDE/SHOW/ENABLE/DISABLE) evaluated on init and on every data change.
5. Provide extensible renderer selection using tester/rank + registry.
6. Support arrays (add/remove/reorder) and optionally LiveView streams for efficient DOM updates.
7. Provide a demo Phoenix app and a testing approach mirroring `a2ui_lv` patterns (scenario-based demo + LiveViewTest coverage).

### Non-goals (v1)

- Full parity with every JSON Forms renderer set (Material/Vuetify/etc.).
- Full JSON Schema dialect coverage on day one (esp. remote `$ref`, complex combinators, advanced formats).
- Complex client-side widgets out of the box (date-time pickers, async selects, etc.); hooks/extensions may be added later.

---

## 3) Architecture overview

Model the implementation similarly to `a2ui_lv`: a Phoenix-free core "engine" + a thin Phoenix adapter layer.

### 3.1 Core modules (pure, testable)

- `JsonFormsLV.State` (struct)
- `JsonFormsLV.Engine` (reducer-style pure functions)
- `JsonFormsLV.Path` (scope/pointer -> data path; path parsing/joining)
- `JsonFormsLV.Data` (get/set/update at path)
- `JsonFormsLV.SchemaResolver` behaviour (optional `$ref` resolving / preprocessing)
- `JsonFormsLV.Validator` behaviour (compile/validate schema, return normalized errors)
- `JsonFormsLV.Errors` (normalize + merge + map errors to controls)
- `JsonFormsLV.Rules` (evaluate rule conditions, derive visibility/enabled flags)
- `JsonFormsLV.Registry` (renderer/cell registry)
- `JsonFormsLV.Dispatch` (pick best renderer given UISchema + schema fragment + context)
- `JsonFormsLV.Coercion` (coerce browser params into typed values based on schema fragment)
- `JsonFormsLV.I18n` (translation key selection / translator interface)

### 3.2 Phoenix adapter modules

- `JsonFormsLV.Phoenix.Components`:
  - `<.json_forms ... />` top-level component
  - `Dispatch.render/1` that emits the chosen renderer component
  - a small set of default renderers/cells (MVP)
- `JsonFormsLV.Phoenix.Events`:
  - helpers for emitting consistent `phx-*` events
  - helpers for decoding event payloads into engine actions

### 3.3 Dataflow

1. Library receives `{schema, uischema, data}` and options.
2. `Engine.init/1` compiles schema (and optionally resolves refs), applies defaults (optional), validates, evaluates rules, builds derived caches.
3. Render phase dispatches renderers by walking the UISchema tree.
4. User changes trigger LiveView events:
   - decode input -> coerce -> `Engine.update_data/4`
   - revalidate (depending on validation mode) + re-evaluate rules
   - re-render via LV diff; arrays may use streams

---

## 4) State model

### 4.1 `JsonFormsLV.State` (core struct)

Required fields (v1):

- `schema :: map()`
- `uischema :: map()`
- `data :: map() | list() | scalar()`
- `validation_mode :: :validate_and_show | :validate_and_hide | :no_validation`
  - mapping:
    - `"ValidateAndShow"` -> `:validate_and_show`
    - `"ValidateAndHide"` -> `:validate_and_hide`
    - `"NoValidation"` -> `:no_validation`
- `validator :: %{module: module(), compiled: term()}`
- `errors :: [JsonFormsLV.Error]` (merged validator + additional)
- `additional_errors :: [JsonFormsLV.Error]`
- `touched :: MapSet.t()` of data paths (used to gate error display for per-input binding)
- `rule_state :: %{element_id_or_path => %{visible?: boolean(), enabled?: boolean()}}`
- `registry :: JsonFormsLV.Registry.t()`
- `i18n :: %{locale: String.t() | nil, translate: (String.t(), String.t() -> String.t()) | nil}`
- `readonly :: boolean()`
- `opts :: map()` (renderer config, theme tokens, performance flags)

Recommended derived/cached fields (v1):

- `schema_index :: term()` (precomputed schema pointer lookup/index)
- `uischema_index :: term()` (optional id/path index)
- `array_ids :: %{data_path => [String.t()]}` (stable ids for array items, if needed)

### 4.2 Error model

Normalize errors to an AJV-like shape for predictable mapping and external errors compatibility:

`JsonFormsLV.Error`:

- `instance_path :: String.t()` (AJV style, e.g. `"/lastname"` or `"/items/0/name"`)
- `message :: String.t()`
- `keyword :: String.t() | nil`
- `schema_path :: String.t() | nil`
- `params :: map()`
- `source :: :validator | :additional`

Rules:

- `Engine` MUST merge validator errors + `additional_errors`.
- Merge SHOULD de-duplicate by `{instance_path, message, keyword, schema_path}`.

---

## 5) Paths, binding, and input naming

### 5.1 `scope` -> data path

Given a scope like `#/properties/foo/properties/bar`, map to data path `"foo.bar"`.

Core functions (v1):

- `JsonFormsLV.Path.schema_pointer_to_data_path/1 :: String.t() -> String.t()`
- `JsonFormsLV.Path.parse_data_path/1 :: String.t() -> [segment]` (string keys + integer indices)
- `JsonFormsLV.Path.join/2 :: base_path, rel_path -> String.t()`
- `JsonFormsLV.Path.data_path_to_instance_path/1 :: "foo.bar.0" -> "/foo/bar/0"`
- `JsonFormsLV.Path.instance_path_to_data_path/1 :: "/foo/bar/0" -> "foo.bar.0"`

### 5.2 Binding strategies

Support two strategies; both must render inside a `<.form>`.

Strategy A: Form-level `phx-change` (simple, heavier payload)

- Inputs use names like `jf[foo][bar]`.
- LV receives all params + `"_target"`; library extracts changed path and value.

Strategy B: Per-control events (scales better; default)

- Each control emits `"jf:change"` with `path` + `value` (and optional `meta`).
- Prefer `Phoenix.LiveView.JS.push/2` to provide structured payloads consistently.

`JsonFormsLV.Phoenix.Components` MUST support both via `binding: :form_level | :per_input`.

---

## 6) Engine API (core)

### 6.1 Reducer-style actions

The core engine is pure and returns a new state.

- `Engine.init(schema, uischema, data, opts) :: State.t()`
- `Engine.update_data(state, data_path, raw_value, meta) :: State.t()`
- `Engine.update_core(state, %{schema?: map(), uischema?: map(), opts?: map()}) :: State.t()`
- `Engine.set_additional_errors(state, additional_errors) :: State.t()`
- `Engine.set_validation_mode(state, mode) :: State.t()`
- `Engine.set_readonly(state, boolean) :: State.t()`

### 6.2 Update pipeline

`update_data` MUST:

1. Resolve the schema fragment for `data_path` (or scope-derived path) for coercion and validation context.
2. Coerce `raw_value` based on schema (type/format) and input kind.
3. Update `data` at `data_path`.
4. Update `touched` (if `meta.touch?`).
5. Re-evaluate rules.
6. Validate (unless `:no_validation`), then merge in `additional_errors`.

---

## 7) JSON Schema support (v1)

### 7.1 Validator behaviour

Define a pluggable validator interface:

```elixir
defmodule JsonFormsLV.Validator do
  @callback compile(schema :: map(), opts :: keyword()) :: {:ok, compiled :: term()} | {:error, term()}
  @callback validate(compiled :: term(), data :: term(), opts :: keyword()) :: [JsonFormsLV.Error.t()]
  @callback validate_fragment(compiled :: term(), fragment_pointer :: String.t(), value :: term(), opts :: keyword()) ::
              :ok | [JsonFormsLV.Error.t()]
end
```

Notes:

- `validate_fragment/4` exists to make rule evaluation cheap (validate only the condition fragment against a value).
- If the chosen validator cannot validate fragments efficiently, it MAY fall back to full validation and filter errors.

Default validator recommendation (implementation choice, not required by spec):

- `:xema` (Hex: `{:xema, "~> 0.17"}`) because it supports JSON Schema-style validation beyond draft4.

### 7.2 `$ref` resolving

JSON Forms commonly expects schemas to be dereferenced up front (docs demonstrate `$RefParser.dereference` / `JsonRefs.resolveRefs`).

Spec requirements:

- v1 MUST support internal refs (same-document, JSON Pointer refs) at least for:
  - `#/definitions/...` and/or `$defs` (depending on schema draft)
  - `#/properties/...` paths
- v1 MAY support remote refs (`http(s)://...`) via a user-provided resolver behaviour:

```elixir
defmodule JsonFormsLV.SchemaResolver do
  @callback resolve(schema :: map(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
end
```

If remote refs are not supported by default, the Phoenix adapter MUST document that the caller should supply a pre-resolved schema.

### 7.3 Defaults

Optional (but desirable) in v1:

- When `opts[:apply_defaults] == true`, `Engine.init/4` SHOULD apply JSON Schema defaults to missing fields.
- Defaults application MUST be deterministic and MUST NOT overwrite user-provided data.

---

## 8) UISchema support and rendering

### 8.1 Minimum UISchema element coverage (v1)

MUST implement:

- `Control`
- `VerticalLayout`
- `HorizontalLayout`

SHOULD implement:

- `Group`
- `Label`
- `Categorization` (tabs)
- Array rendering for `type: "Control"` where schema at scope is `type: "array"`

### 8.2 Options and label behavior

- `Control.label` MAY be:
  - string (explicit label)
  - boolean `false` (suppress label)
  - omitted: fall back to schema `title`, then property name
- `uischema.options` is renderer-specific; the library MUST pass it through to renderers.

### 8.3 Readonly and enabled/disabled

- Global `readonly` disables all controls regardless of rules.
- Rules may set per-element enabled/disabled:
  - disabled controls MUST render with `disabled` attribute and SHOULD show a disabled style.

---

## 9) Renderer registry and dispatch

### 9.1 Registry model

Renderers are selected by tester rank:

```elixir
defmodule JsonFormsLV.Renderer do
  @callback tester(uischema :: map(), schema_fragment :: map() | nil, ctx :: map()) ::
              non_neg_integer() | :not_applicable
  @callback render(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
end
```

The registry holds:

- `control_renderers :: [{module(), opts :: keyword()}]`
- `layout_renderers :: [{module(), opts :: keyword()}]`
- `cell_renderers :: [{module(), opts :: keyword()}]` (optional split)

Dispatch rules:

- Compute all applicable ranks (ignore `:not_applicable`).
- Highest rank wins; ties resolved by registration order (first wins).

### 9.2 Control vs cell split (recommended)

- Control renderer: label, description, wrapper, error display, disabled/visible gating.
- Cell renderer: the actual input widget based on schema type/format/options.

This mirrors JSON Forms structure and makes customization predictable.

---

## 10) Validation

### 10.1 Validation modes

Validation modes follow JSON Forms core `ValidationMode`:

- `:validate_and_show`:
  - validate and expose errors to renderers
- `:validate_and_hide`:
  - validate but hide errors in UI (state retains them)
- `:no_validation`:
  - skip validator errors; `additional_errors` MAY still be shown depending on `opts`

### 10.2 `additionalErrors`

Phoenix adapter MUST accept `additional_errors` shaped like AJV `ErrorObject` subset:

```elixir
%{
  "instancePath" => "/lastname",
  "message" => "New error",
  "schemaPath" => "",
  "keyword" => "",
  "params" => %{}
}
```

Core MUST normalize these into `JsonFormsLV.Error` and merge with validator errors.

### 10.3 Error mapping to controls

- Control has a bound data path.
- Convert `error.instance_path` to a data path and associate errors whose instance path equals the control path or is a descendant (configurable; default: descendant included).
- Renderers receive:
  - `errors_for_control :: [JsonFormsLV.Error]`
  - `show_errors?` (derived from validation mode + touched/submit gating)

### 10.4 "Touched" gating

For per-input binding, the library MUST track touched paths and only show errors for touched controls until submit.

For form-level binding, the library MAY integrate with LiveView's `used_input?` mechanism (optional optimization/UX improvement), but v1 should not require it.

---

## 11) Rules

### 11.1 Rule schema (JSON Forms)

Rules have the shape:

```json
"rule": {
  "effect": "HIDE" | "SHOW" | "ENABLE" | "DISABLE",
  "condition": {
    "scope": "<UI Schema scope>",
    "schema": { /* JSON Schema */ }
  }
}
```

Optional:

- `failWhenUndefined: true` causes the condition to fail if the scope resolves to undefined.

### 11.2 Rule evaluation algorithm (v1)

For each UISchema element with a rule:

1. Resolve `condition.scope` to a data path.
2. Read value at that path:
   - if undefined and `failWhenUndefined` -> condition false
   - if undefined and not `failWhenUndefined` -> condition true (JSON Forms behavior)
3. Validate value against `condition.schema` (fragment validation).
4. Apply effect:
   - HIDE: `visible? = false` when condition true
   - SHOW: `visible? = true` when condition true (default visible otherwise)
   - DISABLE: `enabled? = false` when condition true
   - ENABLE: `enabled? = true` when condition true (default enabled otherwise)

Rule state storage:

- Keyed by a stable element identifier (preferred: explicit `uischema.id` if present; fallback: a generated path in UISchema tree).

---

## 12) Arrays and LiveView streams

### 12.1 Array interactions

Array operations are modeled as explicit engine actions:

- `{:add_item, data_path, default_item}`
- `{:remove_item, data_path, index_or_id}`
- `{:move_item, data_path, from, to}`

### 12.2 Stable identity

To avoid DOM churn (and to support LiveView streams), array items SHOULD have stable ids.

v1 strategy:

- If the item is an object and contains a configured `id`-like field (default: `"id"`), use it.
- Otherwise, generate a UUID and store it in `state.array_ids[data_path]` aligned by index.

### 12.3 LiveView streams (optional, but planned)

If `opts[:stream_arrays] == true`:

- Array item containers render with `phx-update="stream"`.
- Array updates use `stream_insert/4`, `stream_delete/3`, and reorder patterns.

The demo app SHOULD include a "streaming arrays" scenario similar in spirit to `a2ui_lv`'s streaming demo and should include LiveViewTest assertions that DOM ids remain stable across operations.

---

## 13) i18n

### 13.1 i18n contract

Phoenix adapter accepts:

- `i18n: %{locale: String.t(), translate: (key, default_message -> translated_message)}`

UISchema may provide:

- `i18n: "customKey"` on elements; label keys can be derived from this.

### 13.2 Elixir-friendly integration

Provide a `JsonFormsLV.I18n.translate/3` helper that:

- prefers `uischema["i18n"]` as key when present
- falls back to `uischema["label"]` or schema `title`
- delegates to user `translate` callback

Offer a first-party adapter for Gettext in the demo app (not required in core).

---

## 14) Phoenix component API (v1)

### 14.1 Top-level component

Provide a function component:

`<.json_forms id=... schema=... uischema=... data=... />`

Attributes (v1):

- `id` (required)
- `schema` (required)
- `uischema` (required; v1 does not auto-generate)
- `data` (required)
- `state` (optional precomputed `JsonFormsLV.State`; if provided, renderer uses it)
- `validation_mode` (default `:validate_and_show`)
- `additional_errors` (default `[]`)
- `readonly` (default `false`)
- `i18n` (optional)
- `binding` (`:per_input` default, `:form_level` optional)
- `renderers` (custom renderer registrations)
- `opts` (theme/layout/perf config)
- `on_change` (event name; default `"jf:change"`)
- `on_submit` (event name; default `"jf:submit"`)

### 14.2 Events and payloads

Per-input change (recommended):

- event: `"jf:change"`
- payload:
  - `"path"`: data path (e.g. `"foo.bar"`)
  - `"value"`: raw string or structured input value
  - `"kind"`: `"change"` | `"input"` | `"blur"` (optional)
  - `"meta"`: map, e.g. `%{"touch" => true, "input_type" => "text"}`

Form-level change:

- standard LV form payload plus `"_target"`; library extracts `path` + `value` internally.

Array operations:

- `"jf:add_item"`, `"jf:remove_item"`, `"jf:move_item"` with payload including `path` and `index/from/to`.

Submit:

- `"jf:submit"` triggers final validation + sets all fields touched (or uses a submit gating flag).

### 14.3 Controlled vs self-contained usage

Controlled (recommended):

- parent LV owns `state` assigns and calls `Engine.*` in `handle_event/3`.

Self-contained LiveComponent (optional, later milestone):

- `<.live_component module={JsonFormsLV.Phoenix.FormComponent} ... />`
- component handles `"jf:*"` events and exposes callbacks/messages to parent.

---

## 15) Security and correctness

- UISchema/schema are untrusted input:
  - labels/descriptions MUST be escaped; HTML rendering must be opt-in and sanitized.
- Avoid atom leaks: schema/uischema keys are strings; never convert arbitrary keys to atoms.
- DOM id safety:
  - derive DOM ids from `(form_id, uischema_element_id_or_path, data_path)` and a stable hash.
- Performance:
  - compile schema once per state; consider caching compiled schemas by hash (ETS) in later versions.
  - per-input binding should be the default to avoid huge payloads.

---

## 16) Testing strategy (inspired by `a2ui_lv`)

### 16.1 Unit tests (pure core)

Use ExUnit (async) for:

- `Path` conversions (scope pointer <-> data path <-> instancePath)
- `Data` get/set/update at path (including arrays)
- `Coercion` correctness (string -> int/float/bool/nil)
- `Engine.update_data` pipeline invariants (touched, validation, rules)
- `Rules` behavior including `failWhenUndefined`
- `Errors` merge and mapping

Optional: add StreamData property tests for round-trip path conversion and for "update at path does not modify other branches".

### 16.2 LiveView integration tests (demo app)

In `demo/` add LiveView scenarios and test them with:

- `Phoenix.LiveViewTest` (`live/2`, `render_change/2`, `render_click/1`)
- `LazyHTML` for robust HTML assertions (as used in `a2ui_lv`)

Minimum scenarios for v1 tests:

- basic controls (string/integer/boolean)
- enum select
- nested object paths
- rules hide/disable
- validation mode toggle
- additional errors injection
- array add/remove (and streaming if enabled)

---

## 17) Demo application requirements (v1)

The repository already contains `demo/` (Phoenix app). v1 SHOULD evolve it into a scenario-based showcase similar to `a2ui_lv/demo`:

- `/` page links to `/demo` (LiveView)
- `/demo` supports scenario selection:
  - "Basic form"
  - "Rules"
  - "Validation modes"
  - "Readonly"
  - "Arrays" (optionally streaming)
  - "i18n toggle"
  - "Custom renderer"
- Debug panel on the page:
  - shows current `data` (pretty JSON)
  - shows current errors (normalized)
  - shows derived rule state (visible/enabled flags)

---

## 18) Incremental implementation plan

This plan is ordered to keep core pure/testable, ship value early, and mirror the proven `a2ui_lv` approach (engine first, Phoenix adapter thin, scenario-based demo + tests).

### Milestone 0: Repo hygiene (0.5 day)

- Rename/introduce namespaces consistently:
  - prefer `JsonFormsLV.*` module namespace (keep OTP app `:json_form_lv` unless you intentionally rename).
- Add basic docs scaffolding in `README.md` pointing to this spec.

Acceptance:

- `mix test` passes in root and in `demo/`.

### Milestone 1: Paths + data updates (1-2 days)

- Implement `JsonFormsLV.Path`:
  - `schema_pointer_to_data_path/1`
  - `data_path_to_instance_path/1`, `instance_path_to_data_path/1`
  - join/parse helpers
- Implement `JsonFormsLV.Data`:
  - `get/2`, `put/3`, `update/3` for map/list/scalar roots
- Implement `Engine.update_data/4` without validation/rules (just update + touched).

Acceptance:

- Unit tests cover nested objects + arrays.

### Milestone 2: UISchema walk + minimal Phoenix rendering (2-4 days)

- Implement `Dispatch.render/1` to walk UISchema and render nodes.
- Implement default renderers:
  - `VerticalLayout`, `HorizontalLayout`, `Control`
- Implement default cells:
  - string input
  - integer/number input (text + inputmode numeric)
  - boolean checkbox
- Add per-input event emission using `JS.push` (path + value).

Acceptance:

- Demo renders a basic form; LiveView change events update `data`.
- LiveViewTest asserts changing an input updates debug JSON.

### Milestone 3: Validation (2-4 days)

- Add `JsonFormsLV.Validator` behaviour and a default implementation (likely Xema).
- Implement `JsonFormsLV.Errors` normalization + merging:
  - validator errors -> `JsonFormsLV.Error`
  - additional errors -> `JsonFormsLV.Error`
  - merge + de-dup
- Implement validation modes:
  - show/hide/no validation
- Implement error mapping to controls and touched gating.

Acceptance:

- Demo scenario shows errors after interaction (touched) and on submit.
- LiveViewTest covers validation modes and additional errors injection.

### Milestone 4: Rules (2-4 days)

- Implement `JsonFormsLV.Rules`:
  - parse rule objects
  - resolve scope -> value
  - validate condition schema fragment
  - apply effect to derive visible/enabled flags
- Wire rules into renderers:
  - hidden elements not rendered
  - disabled controls render disabled

Acceptance:

- Demo scenario shows dynamic hide/disable behavior.
- Unit tests cover `failWhenUndefined` behavior.

### Milestone 5: Enums, formats, and richer controls (2-5 days)

- Add enum select renderer/cell (`enum` + `oneOf` basic support).
- Add format-aware widgets:
  - `format: "date"` -> `<input type="date">` (or text fallback)
  - `format: "date-time"` -> `<input type="datetime-local">` (or text fallback)
- Add `Label` and `Group` renderers.

Acceptance:

- Demo includes enum + date fields; tests cover value coercion and validation.

### Milestone 6: Arrays + (optional) streams (3-7 days)

- Implement array control renderer:
  - add/remove items
  - optional reorder
  - support `uischema.options.detail` minimally (inline detail + generated later)
- Implement stable ids for items.
- Add optional LiveView streams (`opts[:stream_arrays]`) + tests for stability.

Acceptance:

- Demo "Arrays" scenario works; LiveViewTest covers add/remove and (if enabled) stream ids stability.

### Milestone 7: Extensibility + custom renderers (2-5 days)

- Implement registry APIs:
  - register renderer/cell with tester/rank
  - provide helper testers similar to JSON Forms (type checks, scope matching, option presence)
- Demo "Custom renderer" scenario showing:
  - higher-rank renderer overriding default
  - custom options interpreted by renderer

Acceptance:

- Documented extension points; tests cover dispatch choosing custom renderer.

### Milestone 8: i18n + readonly (1-3 days)

- Implement i18n helpers and demo locale toggle.
- Implement global readonly mode (including in renderers + events disabled).

Acceptance:

- Demo toggles locale and readonly; tests assert disabled inputs and translated labels.

---

## 19) Open questions / follow-ups (post-v1)

- UISchema generation when `uischema` is nil (JSON Forms can generate default UISchema).
- Better `$ref` and schema draft support (remote refs, `$id` resolution, `$defs`).
- Advanced combinators (`oneOf`/`anyOf`/`allOf`) and specialized controls (multi-choice, date-time pickers).
- Partial re-rendering / componentization strategies for very large schemas.
- Server-side performance profiling and caching strategy (compiled schema cache + rule condition caches).

