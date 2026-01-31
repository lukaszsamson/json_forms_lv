defmodule JsonFormsLV.RulesRefValidator do
  @behaviour JsonFormsLV.Validator

  def compile(schema, _opts), do: {:ok, schema}
  def validate(_compiled, _data, _opts), do: []

  def validate_fragment(compiled, fragment_pointer, value, _opts) do
    send(self(), {:validate_fragment, compiled, fragment_pointer, value})
    if value == true, do: [], else: [:error]
  end
end
