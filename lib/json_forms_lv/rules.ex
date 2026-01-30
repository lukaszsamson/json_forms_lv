defmodule JsonFormsLV.Rules do
  @moduledoc """
  Evaluate UISchema rules for visibility and enabled state.
  """

  alias JsonFormsLV.{Data, Path}

  @spec evaluate(map(), term(), map() | nil, keyword()) :: map()
  def evaluate(uischema, data, validator, validator_opts \\ []) when is_map(uischema) do
    traverse(uischema, data, validator, validator_opts, "", [], %{})
  end

  @spec element_key(map(), [non_neg_integer()]) :: String.t()
  def element_key(uischema, element_path) do
    case uischema do
      %{"id" => id} when is_binary(id) and id != "" ->
        id

      %{"type" => type} when is_binary(type) ->
        path =
          element_path
          |> Enum.map(&Integer.to_string/1)
          |> Enum.join("/")

        "#{type}@/" <> path

      _ ->
        "Element@/" <>
          (element_path |> Enum.map(&Integer.to_string/1) |> Enum.join("/"))
    end
  end

  @spec render_key(String.t(), String.t()) :: String.t()
  def render_key(element_key, path) when is_binary(element_key) and is_binary(path) do
    element_key <> "|" <> path
  end

  defp traverse(uischema, data, validator, validator_opts, parent_path, element_path, acc) do
    path = element_path_for(uischema, parent_path)
    element_key = element_key(uischema, element_path)
    render_key = render_key(element_key, path)

    rule_state = rule_state_for(uischema, data, validator, validator_opts)
    acc = Map.put(acc, render_key, rule_state)

    case Map.get(uischema, "elements") do
      elements when is_list(elements) ->
        Enum.with_index(elements)
        |> Enum.reduce(acc, fn {child, index}, acc ->
          traverse(child, data, validator, validator_opts, path, element_path ++ [index], acc)
        end)

      _ ->
        acc
    end
  end

  defp element_path_for(%{"type" => "Control", "scope" => scope}, _parent_path)
       when is_binary(scope) do
    Path.schema_pointer_to_data_path(scope)
  end

  defp element_path_for(_uischema, parent_path), do: parent_path

  defp rule_state_for(%{"rule" => rule}, data, validator, validator_opts) when is_map(rule) do
    effect = Map.get(rule, "effect")
    condition = Map.get(rule, "condition", %{})
    fail_when_undefined = Map.get(rule, "failWhenUndefined", false)

    condition_true? =
      condition_true?(condition, data, validator, validator_opts, fail_when_undefined)

    apply_effect(effect, condition_true?)
  end

  defp rule_state_for(_uischema, _data, _validator, _validator_opts),
    do: %{visible?: true, enabled?: true}

  defp condition_true?(
         %{"scope" => scope, "schema" => schema},
         data,
         validator,
         opts,
         fail_when_undefined
       )
       when is_binary(scope) and is_map(schema) do
    path = Path.schema_pointer_to_data_path(scope)

    case Data.get(data, path) do
      {:ok, value} ->
        valid_schema?(schema, value, validator, opts)

      {:error, _} ->
        not fail_when_undefined
    end
  end

  defp condition_true?(_condition, _data, _validator, _opts, _fail_when_undefined), do: false

  defp valid_schema?(_schema, _value, nil, _opts), do: false

  defp valid_schema?(schema, value, validator, opts) when is_map(validator) do
    module = validator.module
    validator_opts = opts || []

    case module.compile(schema, validator_opts) do
      {:ok, compiled} ->
        module.validate(compiled, value, validator_opts) == []

      {:error, _} ->
        false
    end
  end

  defp apply_effect("HIDE", true), do: %{visible?: false, enabled?: true}
  defp apply_effect("HIDE", false), do: %{visible?: true, enabled?: true}
  defp apply_effect("SHOW", true), do: %{visible?: true, enabled?: true}
  defp apply_effect("SHOW", false), do: %{visible?: false, enabled?: true}
  defp apply_effect("DISABLE", true), do: %{visible?: true, enabled?: false}
  defp apply_effect("DISABLE", false), do: %{visible?: true, enabled?: true}
  defp apply_effect("ENABLE", true), do: %{visible?: true, enabled?: true}
  defp apply_effect("ENABLE", false), do: %{visible?: true, enabled?: false}
  defp apply_effect(_effect, _condition_true), do: %{visible?: true, enabled?: true}
end
