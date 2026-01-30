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
- **i18n**: JSON Forms accepts `i18n: %{locale, translate, translateError}` and UISchema elements may carry an `i18n` key.
- **readonly**: JSON Forms can operate in a global readonly mode (all controls disabled).

### JSON Schema dialect expectations

- JSON Forms historically targets JSON Schema draft-07 in many examples and ecosystems; v1 SHOULD aim for draft-07 semantics.
- The library MUST treat schema draft support as a validator concern:
  - if the validator supports draft-2019-09/2020-12 keywords (e.g. `$defs`, `if/then/else`), the library MAY support them,
  - but v1 MUST clearly document which drafts/keywords are covered by the default validator implementation.
- JSON Forms validation examples use AJV configured to produce many errors (e.g. `allErrors: true`) and include keyword/schema-path details; the default Elixir validator SHOULD return as many errors as practical and populate `keyword/schema_path/params` when available for better parity.

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
- `JsonFormsLV.Event` (normalize event payloads and action decoding/encoding)
- `JsonFormsLV.Path` (scope/pointer -> data path; path parsing/joining)
- `JsonFormsLV.Data` (get/set/update at path)
- `JsonFormsLV.Schema` (schema pointer/data-path resolution helpers)
- `JsonFormsLV.SchemaResolver` behaviour (`$ref` resolving / preprocessing)
- `JsonFormsLV.Validator` behaviour (compile/validate schema, return normalized errors)
- `JsonFormsLV.Errors` (normalize + merge + map errors to controls)
- `JsonFormsLV.Rules` (evaluate rule conditions, derive visibility/enabled flags)
- `JsonFormsLV.Registry` (renderer/cell registry)
- `JsonFormsLV.Dispatch` (pick best renderer given UISchema + schema fragment + context)
- `JsonFormsLV.Coercion` (coerce browser params into typed values based on schema fragment)
- `JsonFormsLV.I18n` (translation key selection / translator interface)
- `JsonFormsLV.Limits` (central safety limits: max elements, depth, errors, sizes)

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
2. `Engine.init/4` resolves schema refs (via `SchemaResolver`), compiles schema, applies defaults (optional), validates, evaluates rules, and builds derived caches.
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
- `validator_opts :: keyword()` (validator configuration, e.g. custom formats/keywords)
- `errors :: [JsonFormsLV.Error]` (merged validator + additional)
- `additional_errors :: [JsonFormsLV.Error]`
- `touched :: MapSet.t()` of data paths (used to gate error display for per-input binding)
- `submitted :: boolean()` (true after first submit attempt; gates error visibility)
- `rule_state :: %{element_id_or_path => %{visible?: boolean(), enabled?: boolean()}}`
- `registry :: JsonFormsLV.Registry.t()`
- `i18n :: %{locale: String.t() | nil, translate: (String.t(), String.t() | nil, map() -> String.t() | nil) | nil, translate_error: (JsonFormsLV.Error.t(), map() -> String.t() | nil) | nil}`
- `readonly :: boolean()` (global, form-wide)
- `opts :: map()` (renderer config, theme tokens, performance flags)

Recommended derived/cached fields (v1):

- `schema_index :: term()` (precomputed schema pointer lookup/index)
- `uischema_index :: term()` (optional id/path index)
- `array_ids :: %{data_path => [String.t()]}` (stable ids for array items, if needed)
- `raw_inputs :: %{data_path => String.t()}` (optional: preserve raw input strings when coercion fails, e.g. invalid numeric typing)

### 4.1.1 UISchema element keys and render keys

Several subsystems need a stable key per rendered element (rules, DOM ids, caches). v1 defines:

- `element_key`: identifies the UISchema element template
- `render_key`: identifies a particular rendering of that template at a specific `path` (important for arrays where the same template is rendered multiple times)

Keying algorithm (v1):

1. If `uischema["id"]` is a non-empty string, `element_key = uischema["id"]`.
2. Otherwise, compute `element_key` from the UISchema tree position:
   - walk from root to the element, recording each container index within its `"elements"` list,
   - join indices with `"/"` and prefix with the element `"type"`.
   - Example: `"Control@/0/2"` means a `Control` that is the 3rd child of the 1st child of the root.
3. Compute `render_key = element_key <> \"|\" <> path`.

Requirements:

- `element_key` MUST be stable for the same UISchema as long as element order does not change.
- `render_key` MUST be used when caching rule results for array item instances.

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
- The engine SHOULD cap stored errors using `JsonFormsLV.Limits` (e.g. keep first N errors deterministically) to avoid DoS via pathological schemas/data.

---

## 5) Paths, binding, and input naming

### 5.1 `scope` -> data path

Given a scope like `#/properties/foo/properties/bar`, map to data path `"foo.bar"`.

Edge cases and requirements:

- The scope is a URI fragment JSON Pointer; it MAY be `"#"` to reference the root.
- JSON Pointer escaping MUST be supported:
  - `~1` decodes to `/`
  - `~0` decodes to `~`
- AJV `instancePath` values are JSON Pointer-like; conversions between `instance_path` and `data_path` MUST apply the same escaping/decoding rules.
- For array schemas, pointers commonly include `items` segments. `schema_pointer_to_data_path/1` MUST:
  - ignore schema-navigation segments like `"properties"` and `"items"`,
  - emit data-path segments that correspond to actual object keys, and
  - when a tuple index appears under `"items"` (e.g. `"items", "0"`), include the index in the resulting data path.
  Examples:
  - `#/properties/comments/items/properties/message` -> `"comments.message"`
  - `#/properties/pair/items/0/properties/left` -> `"pair.0.left"`
- The library MUST support `scope: "#"` for rules and scopes referencing the full data instance, mapping to `""` (empty data path).

Core functions (v1):

- `JsonFormsLV.Path.schema_pointer_to_data_path/1 :: String.t() -> String.t()`
- `JsonFormsLV.Path.parse_data_path/1 :: String.t() -> [segment]` (string keys + integer indices)
- `JsonFormsLV.Path.join/2 :: base_path, rel_path -> String.t()`
- `JsonFormsLV.Path.data_path_to_instance_path/1 :: "foo.bar.0" -> "/foo/bar/0"`
- `JsonFormsLV.Path.instance_path_to_data_path/1 :: "/foo/bar/0" -> "foo.bar.0"`

Schema fragment resolution (required for coercion, validation, renderer selection, and arrays):

- `JsonFormsLV.Schema.resolve_pointer(schema :: map(), schema_pointer :: String.t()) :: {:ok, map()} | {:error, term()}`
- `JsonFormsLV.Schema.resolve_at_data_path(schema :: map(), data_path :: String.t()) :: {:ok, map()} | {:error, term()}`
  - `resolve_at_data_path/2` MUST walk `properties` for object keys and `items` for list indices.

### 5.2 Binding strategies

Support two strategies; both must render inside a `<.form>`.

Strategy A: Form-level `phx-change` (simple, heavier payload)

- Inputs use names like `jf[foo][bar]`.
- LV receives all params + `"_target"`; library extracts changed path and value.

Strategy B: Per-control events (scales better; default)

- Each control emits `"jf:change"` with `path` + `value` (and optional `meta`).
- Prefer `Phoenix.LiveView.JS.push/2` to provide structured payloads consistently.
- Degradation: per-control events rely on LiveView JS; the library SHOULD provide `binding: :form_level` as a no-JS fallback.

`JsonFormsLV.Phoenix.Components` MUST support both via `binding: :form_level | :per_input`.

---

## 6) Engine API (core)

### 6.1 Reducer-style actions

The core engine is pure (Phoenix-free). Engine functions MUST NOT perform IO.

For robust error handling (invalid schema, invalid uischema, invalid paths), state-changing functions MUST return `{:ok, state} | {:error, reason}`. The Phoenix adapter MAY provide convenience wrappers that raise or return the original state on error, but the core API must be explicit.

Core API (v1):

- `Engine.init(schema, uischema, data, opts) :: {:ok, State.t()} | {:error, term()}`
- `Engine.dispatch(state, action) :: {:ok, State.t()} | {:error, term()}`
  - action is one of:
    - `{:update_data, data_path, raw_value, meta}`
    - `{:touch, data_path}`
    - `:touch_all`
    - `{:add_item, data_path, opts}`
    - `{:remove_item, data_path, index_or_id}`
    - `{:move_item, data_path, from, to}`
    - `{:set_additional_errors, additional_errors}`
    - `{:set_validation_mode, mode}`
    - `{:set_readonly, boolean}`
    - `{:update_core, %{schema?: map(), uischema?: map(), opts?: map()}}`

Convenience wrappers (recommended, optional in core):

- `Engine.update_data(state, data_path, raw_value, meta) :: {:ok, State.t()} | {:error, term()}`
- `Engine.touch(state, data_path) :: {:ok, State.t()} | {:error, term()}`
- `Engine.touch_all(state) :: {:ok, State.t()}`
- `Engine.add_item(state, data_path, opts) :: {:ok, State.t()} | {:error, term()}`
- `Engine.remove_item(state, data_path, index_or_id) :: {:ok, State.t()} | {:error, term()}`
- `Engine.move_item(state, data_path, from, to) :: {:ok, State.t()} | {:error, term()}`
- `Engine.set_additional_errors(state, additional_errors) :: {:ok, State.t()}`
- `Engine.set_validation_mode(state, mode) :: {:ok, State.t()}`
- `Engine.set_readonly(state, boolean) :: {:ok, State.t()}`
- `Engine.update_core(state, updates) :: {:ok, State.t()} | {:error, term()}`

### 6.2 Update pipeline

`update_data` MUST:

1. Resolve the schema fragment for `data_path` (or scope-derived path) for coercion and validation context via `JsonFormsLV.Schema.resolve_at_data_path/2`.
2. Coerce `raw_value` based on schema (type/format/union types) and input kind.
3. Update `data` at `data_path`.
4. Update `touched` (for per-input binding: on blur, and/or if `meta.touch? == true`).
5. Update `submitted` if this is a submit action (or `Engine.touch_all/1` was called).
6. Re-evaluate rules (deriving visibility/enabled flags for the rendered tree).
7. Validate (unless `:no_validation`), then merge in `additional_errors`.

Validation timing configuration:

- Default: validate on each `update_data`.
- The Phoenix adapter MUST support a debounced UX via `phx-debounce`/`phx-throttle` and SHOULD expose `opts[:validate_on]`:
  - `:change` (default)
  - `:blur`
  - `:submit`

### 6.3 Coercion rules (v1)

LiveView form params arrive as strings. The engine MUST coerce values based on the bound schema fragment:

- `type: "boolean"`:
  - `"true"`, `"on"`, `true` -> `true`
  - `"false"`, `false`, `nil` -> `false`
- `type: "integer"`:
  - parse base-10 integers
- `type: "number"`:
  - parse floats/decimals (implementation-defined; must be documented)
- `type: "string"`:
  - keep as string (do not trim unless explicitly configured)
- union types (e.g. `type: ["string", "null"]`):
  - treat empty string as `nil` when `"null"` is allowed AND `opts[:empty_string_as_null] == true` (default true for union-with-null)

Coercion failures:

- For inputs where coercion can fail during typing (notably number/integer), the engine SHOULD preserve the raw input in `state.raw_inputs[path]` so the UI can continue to display the user's in-progress value.
- When coercion fails, the engine MUST NOT crash; it MAY either:
  - keep the previous typed data value and only update `raw_inputs`, or
  - store the raw string in data (less JSON-accurate) and rely on validation to surface errors.
  The chosen behavior MUST be documented and covered by tests.

### 6.4 Error handling (v1)

Engine functions that return `{:error, reason}` MUST use stable, pattern-matchable reasons. v1 SHOULD define a small set, e.g.:

- `{:invalid_schema, details}`
- `{:invalid_uischema, details}`
- `{:invalid_path, path}`
- `{:schema_resolution_failed, pointer_or_path, details}`
- `{:validator_compile_failed, details}`
- `{:unsupported_rule_condition, condition}`

The Phoenix adapter SHOULD:

- render a helpful error box in development/test,
- avoid leaking sensitive details in production (log internally, show generic error UI).

---

## 7) JSON Schema support (v1)

### 7.1 Validator behaviour

Define a pluggable validator interface:

```elixir
defmodule JsonFormsLV.Validator do
  @callback compile(schema :: map(), opts :: keyword()) :: {:ok, compiled :: term()} | {:error, term()}
  @callback validate(compiled :: term(), data :: term(), opts :: keyword()) :: [JsonFormsLV.Error.t()]
  @callback validate_fragment(compiled :: term(), fragment_pointer :: String.t(), value :: term(), opts :: keyword()) ::
              [JsonFormsLV.Error.t()]
end
```

Notes:

- `validate_fragment/4` exists to make rule evaluation cheap (validate only the condition fragment against a value).
- Empty list means "valid". If the chosen validator cannot validate fragments efficiently, it MAY fall back to full validation and filter errors.
- The default validator implementation MUST document supported drafts/keywords and SHOULD expose configuration to align with common AJV behaviors (e.g. "return all errors" and populate keyword/schema-path details when possible).

Default validator recommendation (implementation choice, not required by spec):

- `:xema` (Hex: `{:xema, "~> 0.17"}`) because it supports JSON Schema-style validation beyond draft4.

### 7.2 `$ref` resolving

JSON Forms commonly expects schemas to be dereferenced up front (docs demonstrate `$RefParser.dereference` / `JsonRefs.resolveRefs`).

Spec requirements:

- v1 MUST support internal refs (same-document, JSON Pointer refs) at least for:
  - `#/definitions/...` and/or `$defs` (depending on schema draft)
  - `#/properties/...` paths
- v1 MUST define a `SchemaResolver` stage and invoke it during `Engine.init/4` and `Engine.update_core/2` when schema changes.
- v1 MUST NOT perform network IO inside `Engine` by default. If remote refs (`http(s)://...`) are needed, callers MUST pre-resolve schema before calling `Engine.init/4`, or provide a resolver module that is explicitly allowed to do IO (recommended: run it outside LiveView mount via `assign_async` and pass the resolved schema into the engine).

```elixir
defmodule JsonFormsLV.SchemaResolver do
  @callback resolve(schema :: map(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
end
```

Default behavior:

- The library SHOULD ship a default resolver that:
  - resolves internal refs (same-document JSON Pointer refs) to the extent required by the chosen validator, and
  - rejects or leaves untouched remote refs by default with a clear `{:error, {:remote_ref, ref}}` (so failures are explicit).

UISchema references:

- v1 MAY ignore `$ref` inside UISchema, but MUST document that advanced UISchema constructs (e.g. array `options.detail` referencing registered detail uischemas) may require an additional UISchema resolution phase in future versions.

### 7.3 Defaults

Optional (but desirable) in v1:

- When `opts[:apply_defaults] == true`, `Engine.init/4` SHOULD apply JSON Schema defaults to missing fields.
- Defaults application MUST be deterministic and MUST NOT overwrite user-provided data.
- Defaults application SHOULD be recursive:
  - For objects: if a property is absent and has `default`, set it; then recurse into nested objects.
  - For arrays: if the array itself is absent and has `default`, set it; otherwise, do not auto-expand array length. If array items are objects with defaults, defaults apply only to existing items.

---

## 8) UISchema support and rendering

UISchema general requirements (v1):

- Every UISchema element MUST be a map with a `"type"` string.
- Layout elements that contain children MUST use an `"elements"` list.
- Unknown `"type"` values MUST NOT crash rendering; the renderer must fall back to a default "unknown element" renderer (see Section 9.4).

### 8.1 Minimum UISchema element coverage (v1)

MUST implement:

- `Control`
- `VerticalLayout`
- `HorizontalLayout`

SHOULD implement:

- `Group`
- `Label` (uses `"text"` for display text)
- `Categorization` (tabs)
- `Category` (child of `Categorization`)
- Array rendering for `type: "Control"` where schema at scope is `type: "array"`

### 8.2 Options and label behavior

Element shapes (v1 subset):

- `Control`: `%{"type" => "Control", "scope" => "#/properties/...", ...}`
- `VerticalLayout`/`HorizontalLayout`: `%{"type" => "...Layout", "elements" => [ ... ]}`
- `Group`: `%{"type" => "Group", "label" => "...", "elements" => [ ... ]}`
- `Label`: `%{"type" => "Label", "text" => "...", ...}`
- `Categorization`: `%{"type" => "Categorization", "elements" => [category, ...]}`
- `Category`: `%{"type" => "Category", "label" => "...", "elements" => [ ... ]}`

Label resolution (Controls):

- `Control.label` MAY be:
  - string (explicit label)
  - boolean `false` (suppress label)
  - omitted: resolve label in this order:
    1) schema fragment `"title"`
    2) derived from property name (split camelCase/snake_case)

Descriptions / help text:

- Renderers SHOULD support showing help text resolved in this order:
  1) `uischema.options["description"]` (if present)
  2) schema fragment `"description"`

Options passthrough:

- `uischema.options` is renderer-specific; the library MUST pass it through to renderers as a string-keyed map (do not atomize keys).

### 8.3 Readonly and enabled/disabled

Enabled/disabled sources (v1) and precedence:

The renderer MUST compute `effective_enabled?` for each rendered element by combining, in order:

1. Global `readonly` (form-wide) -> disables everything
2. Rule effects `ENABLE`/`DISABLE` for the element
3. UISchema element-level readonly option: `uischema.options["readonly"] == true` (also accept `"readOnly"` as an alias)
4. JSON Schema annotation `readOnly: true` at the bound schema fragment
5. Parent inheritance (a disabled layout/group disables descendants)

Precedence rules:

- Global `readonly` MUST always win (cannot be overridden).
- Schema `readOnly: true` MUST disable the element and MUST NOT be overridden by rules.
- UISchema readonly MUST disable the element and MUST NOT be overridden by rules.
- Parent inheritance MUST always disable descendants, regardless of their own rules.
- Disabled controls MUST render with the `disabled` attribute (not `readonly`) and SHOULD show a disabled style.

### 8.4 Choice controls (enum/oneOf/multi)

The default renderer set SHOULD support these common JSON Forms patterns:

- Single choice:
  - schema has `enum: [...]` or `oneOf: [%{"const" => v, "title" => t}, ...]`
  - default widget: `<select>`
  - if `uischema.options["format"] == "radio"`, render a radio group
- Multiple choice:
  - schema has `type: "array"` with `items.enum` or `items.oneOf` and typically `uniqueItems: true`
  - default widget: `<select multiple>` or a checkbox list (renderer choice)
  - multi-select MUST be derived from the array schema, not from `uischema.options["multi"]`

Multiline strings:

- `uischema.options["multi"] == true` MUST be interpreted as a multiline string hint for `type: "string"` controls (render as `<textarea>` or equivalent), matching JSON Forms behavior.

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
- Highest rank wins; ties resolved by registration order (the earliest registered renderer wins).

### 9.2 Control vs cell split (recommended)

- Control renderer: label, description, wrapper, error display, disabled/visible gating.
- Cell renderer: the actual input widget based on schema type/format/options.

This mirrors JSON Forms structure and makes customization predictable.

### 9.3 Tester context (`ctx`) and renderer assigns contract

Tester context (`ctx`) MUST be a plain map with (at minimum):

- `:root_schema` (full schema map)
- `:schema` (current schema fragment map or nil)
- `:uischema` (current UISchema element map)
- `:path` (current data path, e.g. `"address.street"` or `""` for root)
- `:instance_path` (AJV-style instance path, e.g. `"/address/street"` or `""` for root)
- `:config` (merged opts/config visible to renderers)
- `:i18n` (i18n map or nil)
- `:readonly` (global readonly boolean)

Renderer assigns MUST be stable so third-party renderers are predictable. The Phoenix adapter MUST pass (at minimum) these assigns to renderer `render/1`:

Common assigns (all element types):

- `id` (stable DOM id)
- `uischema` (current element)
- `schema` (schema fragment for this element, if applicable)
- `root_schema` (full schema)
- `data` (root data)
- `path` (data path for this element)
- `instance_path` (AJV instance path for this element)
- `visible?` (derived visibility)
- `enabled?` (derived enabled state)
- `readonly?` (global readonly)
- `options` (string-keyed `uischema.options` map, default `%{}`)
- `i18n` (i18n map, default `%{}`)
- `config` (renderer config)
- `form_id` (top-level id)
- `on_change` / `on_blur` / `on_submit` (event names)
- `target` (optional LiveComponent target for events)

Control/cell additional assigns:

- `value` (value at `path`)
- `label` (resolved label string or nil)
- `description` (resolved description/help string or nil)
- `required?` (boolean derived from parent schema `"required"` list)
- `errors_for_control` (list of errors mapped to this control)
- `show_errors?` (boolean derived from validation mode + touched/submitted)

### 9.4 Fallback renderer

If no renderer returns an applicable rank for a UISchema element, dispatch MUST fall back to a built-in renderer that:

- renders a visible warning in development/test (to make gaps obvious),
- renders a minimal placeholder in production,
- never raises due to unknown element shapes.

### 9.5 Tester helper functions (recommended)

The library SHOULD provide helper testers to make custom renderers ergonomic, e.g.:

- `ui_type_is("Control")`
- `schema_type_is("string" | "number" | "integer" | "boolean" | "array" | "object")`
- `format_is("date" | "date-time" | "email" | ...)`
- `has_option("multi")`
- `scope_ends_with("name")`
- `rank_with(rank, tester_fun)`

---

## 10) Validation

### 10.1 Validation modes

Validation modes follow JSON Forms core `ValidationMode`:

- `:validate_and_show`:
  - validate and expose errors to renderers
- `:validate_and_hide`:
  - validate but hide errors in UI (state retains them)
- `:no_validation`:
  - skip validator errors; `additional_errors` MUST still be exposed to renderers by default

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

Visibility rule (JSON Forms parity):

- `additional_errors` MUST be visible to renderers regardless of `validation_mode` (including `:validate_and_hide` and `:no_validation`) by default.
- `additional_errors` SHOULD NOT be gated by `touched`/`submitted` by default (they come from external sources and should be shown immediately). The library MAY allow opting into touched/submitted gating via `opts`.
- The library MAY offer an explicit opt-out via `opts[:hide_additional_errors?] == true`.

### 10.3 Error mapping to controls

- Control has a bound data path.
- Convert `error.instance_path` to a data path and associate errors whose instance path equals the control path (default).
- The engine MAY support an alternative mapping mode `opts[:error_mapping] == :subtree` which also associates descendant errors (useful for group-level summaries), but this MUST NOT be the default for control-level error rendering.
- Required-error remapping MUST be supported: AJV-style `required` errors often point `instancePath` at the parent object and include the missing property in `params.missingProperty`. In that case, map the error to `parent_path <> "." <> missing_property`.
- Root errors MAY have `instance_path == ""` (empty); these MUST be exposed as "form-level" errors (not attached to a specific control) so the host app can render them.
- Renderers receive:
  - `errors_for_control :: [JsonFormsLV.Error]`
  - `show_errors?` (derived from validation mode + touched/submit gating)

### 10.4 "Touched" gating

For per-input binding, the library MUST track touched paths and only show errors for touched controls until submit.

Visibility derivation:

- `show_errors?` for a control MUST be computed from:
  - `validation_mode` (hide/show)
  - `submitted` (if true, show errors regardless of touched)
  - `touched` (if not submitted, only show errors for touched controls)
- `touched` updates MUST happen before computing `show_errors?` during an update (so blur/change events can reveal errors immediately when appropriate).

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

Defaults:

- Elements without rules default to `visible? = true` and `enabled? = true` (before applying readonly sources and parent inheritance).
- Rule scopes are absolute from the root data (not relative to the element's own binding). `scope: "#"` refers to the full data instance and resolves to the empty data path `""`.

Algorithm:

1. Resolve `condition.scope` to a data path (absolute).
2. Read value at that path:
   - if undefined and `failWhenUndefined` -> condition false
   - if undefined and not `failWhenUndefined` -> condition true (JSON Forms behavior)
3. Validate value against `condition.schema` (fragment validation).
4. Apply effect:
   - HIDE: `visible? = false` when condition true; otherwise `visible? = true`
   - SHOW: `visible? = true` when condition true; otherwise `visible? = false`
   - DISABLE: `enabled? = false` when condition true; otherwise `enabled? = true`
   - ENABLE: `enabled? = true` when condition true; otherwise `enabled? = false`

Unsupported conditions (v1):

- If `condition` is a composed condition (e.g. `{"type": "AND"|"OR", ...}`), the engine MUST return `{:error, {:unsupported_rule_condition, condition}}` (or treat it as false) and MUST document this limitation.

Rule state storage:

- Keyed by a stable element identifier (preferred: explicit `uischema.id` if present; fallback: a generated path in UISchema tree) AND the rendered `path` (to disambiguate repeated templates in arrays).
- Visibility/enabled MUST also be inherited: if a parent layout/group is hidden, all descendants are hidden; if a parent is disabled, descendants are disabled regardless of their own rules.

---

## 12) Arrays and LiveView streams

### 12.1 Array interactions

Array operations are modeled as explicit engine actions:

- `{:add_item, data_path, opts}`
- `{:remove_item, data_path, index_or_id}`
- `{:move_item, data_path, from, to}`

Default item derivation (v1):

- The engine MUST be able to derive a default new item when adding:
  1) if schema for the array has an explicit `"default"` for a new element (rare), use it
  2) else if `items` schema is an object, default to `%{}` and then apply nested defaults (if `apply_defaults` enabled)
  3) else default to `nil` or `""` depending on `items.type` and nullability (see coercion rules)
- Callers MAY override via `opts[:item]` (explicit item value).

### 12.2 Stable identity

To avoid DOM churn (and to support LiveView streams), array items SHOULD have stable ids.

v1 strategy:

- If the item is an object and contains a configured `id`-like field (default: `"id"`), use it.
- Otherwise, generate a UUID and store it in `state.array_ids[data_path]` aligned by index.

### 12.3 LiveView streams (optional, but planned)

If `opts[:stream_arrays] == true`:

- `JsonFormsLV.State` MUST NOT store LiveView stream data. The core state only stores stable ids (`array_ids`). The LiveView adapter is responsible for calling `stream/3`/`stream_insert`/`stream_delete` using those ids.
- Array item containers render with `phx-update="stream"`.
- Array updates use `stream_insert/4`, `stream_delete/3`, and reorder patterns.

The demo app SHOULD include a "streaming arrays" scenario similar in spirit to `a2ui_lv`'s streaming demo and should include LiveViewTest assertions that DOM ids remain stable across operations.

### 12.4 JSON Forms array options (planned v1/v1.1)

Renderers SHOULD support common JSON Forms array options via `uischema.options`:

- `detail`:
  - inline UISchema object: use it as the per-item uischema template
  - `"DEFAULT"`: render items using the default object renderer (derived from `items` schema)
  - `"GENERATED"`: generate a detail uischema from the `items` schema (v1 MAY defer generation)
  - `"REGISTERED"`: resolve a registered uischema by name/id (v1 MAY defer; requires a registry)
- `showSortButtons: true`: render move up/down controls that emit `jf:move_item`
- `elementLabelProp: "name"`: label array items using the specified property from each item (fallback: first primitive property, else index)

Item schema resolution:

- When rendering children inside an array item, the engine MUST pass the `items` schema fragment (and apply tuple-index selection if `items` is a list).

---

## 13) i18n

### 13.1 i18n contract

Phoenix adapter accepts:

- `i18n: %{locale: String.t() | nil, translate: (key, default_message, ctx -> translated_message | nil) | nil, translate_error: (error, translate, ctx -> translated_message | nil) | (error, ctx -> translated_message | nil) | nil}`
  - the adapter MUST accept both `:translate_error` and `"translateError"` keys for convenience (snake_case in Elixir, camelCase in JSON docs/examples).
  - when the provided `translate_error` uses the JSON Forms signature `(error, translate, uischema?)`, the adapter MUST pass the `translate` callback and `uischema` in `ctx` (or an explicit third arg). When only `(error, ctx)` is accepted, the adapter MUST pass `ctx` containing `:translate` and `:uischema`.

UISchema may provide:

- `i18n: "customKey"` on elements (a stable translation key override).

### 13.2 Elixir-friendly integration

Provide `JsonFormsLV.I18n` helpers that:

Context (`ctx`) passed to translation callbacks MUST include (at minimum):

- `:locale`
- `:path` and `:instance_path`
- `:uischema`
- `:schema` and `:root_schema`
- `:error` (for error translations)
- `:config`

Translation key derivation (v1):

1. Determine a base key:
   - prefer `uischema["i18n"]` when present
   - else prefer schema fragment `"i18n"` when present
   - else derive from `path` by:
     - splitting into segments and removing numeric indices (array positions),
     - joining with `"."` (e.g. `"comments.0.message"` -> `"comments.message"`).
2. Derive keys by suffix:
   - control label: `base <> ".label"`
   - description/help: `base <> ".description"`
   - label element text (`type: "Label"`):
     - if `uischema["i18n"]` is present, use it as `base` and derive `base <> ".text"`,
     - otherwise use `uischema["text"]` as the base key directly (no suffix) and fall back to the `text` value if no translation exists.
3. Enum/oneOf option labels:
   - for `enum`: `base <> "." <> to_string(value)`
   - for `oneOf` with `{const, title}`: prefer `title` as default message; key may be `base <> "." <> to_string(const)`.
4. Error translation:
   - if `i18n.translate_error` is provided, call it first
   - else use `i18n.translate` with keys in this order:
     1) `base <> ".error.custom"` (for any error, regardless of source)
     2) `base <> ".error." <> keyword` (if keyword present)
     3) `"error." <> keyword` (if keyword present)
     4) fallback to the error `message` (no translation)

All translation helpers MUST:

- return the provided default message when no translation exists (i.e. callback returns nil),
- avoid raising if the i18n callback fails (Phoenix adapter may log and fall back to defaults).

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
- `context` (optional map; passed through to tester ctx and renderer assigns)
- `validation_mode` (default `:validate_and_show`)
- `additional_errors` (default `[]`)
- `readonly` (default `false`)
- `i18n` (optional)
- `binding` (`:per_input` default, `:form_level` optional)
- `wrap_form` (default `true`; when `false`, caller must wrap in a LiveView form)
- `target` (optional `phx-target` for events; required for LiveComponent integration)
- `renderers` (custom renderer registrations; merged ahead of defaults)
- `cells` (custom cell renderer registrations; merged ahead of defaults)
- `opts` (theme/layout/perf config)
- `on_change` (event name; default `"jf:change"`)
- `on_blur` (event name; default `"jf:blur"`)
- `on_submit` (event name; default `"jf:submit"`)

Renderer registration structure (v1):

- `renderers` and `cells` MUST accept a list of entries where each entry is either:
  - a module implementing `JsonFormsLV.Renderer`, or
  - `{module, keyword_opts}`
  Registration order is significant and is used as the tie-breaker for equal ranks.

Form wrapper ownership (v1):

- By default (`wrap_form: true`), `<.json_forms>` MUST render its own `<.form ...>` wrapper to ensure LiveView binding semantics work.
- If `wrap_form: false`, the component MUST NOT render a form; it MUST assume it is nested under a caller-provided `<.form>`.

### 14.2 Events and payloads

Per-input change (recommended):

- event: `"jf:change"`
- payload:
  - `"path"`: data path (e.g. `"foo.bar"`)
  - `"value"`: raw string or structured input value
  - `"kind"`: `"change"` | `"input"` | `"blur"` (optional)
  - `"meta"`: map, e.g. `%{"touch" => true, "input_type" => "text"}`

Blur / touch:

- event: `"jf:blur"`
- payload:
  - `"path"`: data path
  - `"meta"`: map (optional)

Event helpers:

- Default renderers SHOULD use `JsonFormsLV.Event` helpers to build payloads consistently.

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
- Safety limits (recommended; mirror `a2ui_lv` hardening):
  - cap maximum rendered UISchema elements (e.g. 1000)
  - cap maximum render depth/recursion (e.g. 30)
  - cap maximum error count stored/exposed (e.g. 100)
  - cap maximum data size processed (implementation-defined; should be configurable)
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
- Error edge cases: invalid schema/uischema, unknown scopes, required-error remapping, root errors
- Readonly precedence and inheritance

Optional: add StreamData property tests for round-trip path conversion and for "update at path does not modify other branches".
Optional: add snapshot/golden tests for rendered HTML of key scenarios to catch regressions.
Optional: add lightweight benchmarks for large schemas to detect performance regressions.

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
  - UI: sidebar or tabbed navigation (simple, persistent)
  - "Basic form"
  - "Rules"
  - "Validation modes"
  - "Readonly"
  - "Arrays" (optionally streaming)
  - "i18n toggle"
  - "Custom renderer"
- "Reset" button to restore initial `data`/state for the active scenario.
- Styling: keep it minimal and maintainable (Tailwind in the demo app is recommended).
- Debug panel on the page:
  - shows current `data` (pretty JSON)
  - shows current errors (normalized)
  - shows derived rule state (visible/enabled flags)
  - (optional) JSON editors for schema/uischema/data to speed up experimentation (like `a2ui_lv`'s message panel)

---

## 18) Incremental implementation plan

This plan is ordered to keep core pure/testable, ship value early, and mirror the proven `a2ui_lv` approach (engine first, Phoenix adapter thin, scenario-based demo + tests).

### Milestone 0: Project scaffolding

- Rename/introduce namespaces consistently:
  - prefer `JsonFormsLV.*` module namespace (keep OTP app `:json_form_lv` unless you intentionally rename).
- Add basic docs scaffolding in `README.md` pointing to this spec.
- Add CI that runs `mix test` for root and `demo/` (and formatting checks).
- Add a central `JsonFormsLV.Limits` module and wire default limits into the engine (even if the initial values are permissive).

Acceptance:

- `mix test` passes in root and in `demo/`.

### Milestone 1: Paths + schema resolution + data updates

- Implement `JsonFormsLV.Path`:
  - `schema_pointer_to_data_path/1`
  - `data_path_to_instance_path/1`, `instance_path_to_data_path/1`
  - join/parse helpers
- Implement `JsonFormsLV.Schema`:
  - `resolve_pointer/2`
  - `resolve_at_data_path/2`
- Implement `JsonFormsLV.Data`:
  - `get/2`, `put/3`, `update/3` for map/list/scalar roots
- Implement `Engine.update_data/4` (or `Engine.dispatch/2`) without validation/rules (just update + touched/raw_inputs).

Acceptance:

- Unit tests cover nested objects + arrays.

### Milestone 2: UISchema walk + minimal Phoenix rendering

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

### Milestone 3: Validation + error mapping parity

- Add `JsonFormsLV.SchemaResolver` behaviour and default resolver (internal refs; explicit failure on remote refs by default).
- Add `JsonFormsLV.Validator` behaviour and choose a default implementation.
- Implement `JsonFormsLV.Errors` normalization + merging:
  - validator errors -> `JsonFormsLV.Error`
  - additional errors -> `JsonFormsLV.Error`
  - merge + de-dup
- Implement validation modes:
  - show/hide/no validation
- Implement error mapping to controls and touched gating.
- Add required-error remapping (`required` + `missingProperty`) and root error handling.
- Add i18n error translation hooks (`translate_error` / key derivation) at least for errors.

Acceptance:

- Demo scenario shows errors after interaction (touched) and on submit.
- LiveViewTest covers validation modes and additional errors injection.

### Milestone 4: Rules

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

### Milestone 5: Enums, formats, i18n, and readonly

- Add enum select renderer/cell (`enum` + `oneOf` basic support).
- Add format-aware widgets:
  - `format: "date"` -> `<input type="date">` (or text fallback)
  - `format: "date-time"` -> `<input type="datetime-local">` (or text fallback)
- Add `Label` and `Group` renderers.
- Implement i18n helpers and demo locale toggle (labels, descriptions, and errors).
- Implement global readonly mode + schema/uischema readonly sources (including inheritance).

Acceptance:

- Demo includes enum + date fields; tests cover value coercion and validation.

### Milestone 6: Arrays + (optional) streams

- Implement array control renderer:
  - add/remove items
  - optional reorder
  - support `uischema.options.detail` minimally (inline detail + generated later)
- Implement stable ids for items.
- Add optional LiveView streams (`opts[:stream_arrays]`) + tests for stability.

Acceptance:

- Demo "Arrays" scenario works; LiveViewTest covers add/remove and (if enabled) stream ids stability.

### Milestone 7: Extensibility + custom renderers

- Implement registry APIs:
  - register renderer/cell with tester/rank
  - provide helper testers similar to JSON Forms (type checks, scope matching, option presence)
- Demo "Custom renderer" scenario showing:
  - higher-rank renderer overriding default
  - custom options interpreted by renderer

Acceptance:

- Documented extension points; tests cover dispatch choosing custom renderer.

### Milestone 8: Documentation, telemetry, and polish

- Add ExDoc docs for the public Phoenix API and extension points (registry/testers/renderers).
- Add basic telemetry events for `init`, `update_data`, `validate`, and render dispatch (optional but recommended).
- Add a11y pass in the demo (labels/for, fieldset/legend for groups, aria-invalid, error summaries).

Acceptance:

- ExDoc builds cleanly and public API docs are discoverable.
- Demo a11y baseline is reasonable (manual review + key attributes in place).

---

## 19) Open questions / follow-ups (post-v1)

- UISchema generation when `uischema` is nil (JSON Forms can generate default UISchema).
- Better `$ref` and schema draft support (remote refs, `$id` resolution, `$defs`).
- Advanced combinators (`oneOf`/`anyOf`/`allOf`) and specialized controls (multi-choice, date-time pickers).
- Conditional schemas (`if`/`then`/`else`) and how they interact with rule evaluation and renderer selection.
- `writeOnly` handling for schema properties (e.g. hiding values on re-render).
- Middleware/hooks: JSON Forms supports reducer middleware; decide whether v2 adds an `Engine.dispatch` middleware chain.
- Async schema loading/resolution patterns for LiveView (`assign_async` pre-resolve refs before init).
- Partial re-rendering / componentization strategies for very large schemas.
- Server-side performance profiling and caching strategy (compiled schema cache + rule condition caches).
