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

### Log tester errors

Enable logging for custom tester exceptions:

```elixir
config :json_forms_lv, log_tester_errors: true
```
