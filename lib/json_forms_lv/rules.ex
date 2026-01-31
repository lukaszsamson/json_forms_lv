defmodule JsonFormsLV.Rules do
  @moduledoc """
  Evaluate UISchema rules for visibility and enabled state.
  """

  alias JsonFormsLV.{Data, Path}

  require Logger

  @spec evaluate(map(), term(), map() | nil, keyword()) :: map()
  def evaluate(uischema, data, validator, validator_opts \\ []) when is_map(uischema) do
    {rule_state, _cache} =
      traverse(uischema, data, validator, validator_opts, "", [], %{}, %{})

    rule_state
  end

  @spec evaluate(map(), term(), map() | nil, keyword(), map()) :: {map(), map()}
  def evaluate(uischema, data, validator, validator_opts, cache)
      when is_map(uischema) and is_map(cache) do
    traverse(uischema, data, validator, validator_opts, "", [], %{}, cache)
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

  defp traverse(uischema, data, validator, validator_opts, parent_path, element_path, acc, cache) do
    path = element_path_for(uischema, parent_path)
    element_key = element_key(uischema, element_path)
    render_key = render_key(element_key, path)

    {rule_state, cache} = rule_state_for(uischema, data, validator, validator_opts, cache)
    acc = Map.put(acc, render_key, rule_state)

    case Map.get(uischema, "elements") do
      elements when is_list(elements) ->
        Enum.with_index(elements)
        |> Enum.reduce({acc, cache}, fn {child, index}, {acc, cache} ->
          traverse(
            child,
            data,
            validator,
            validator_opts,
            path,
            element_path ++ [index],
            acc,
            cache
          )
        end)

      _ ->
        {acc, cache}
    end
  end

  defp element_path_for(%{"type" => "Control", "scope" => scope}, _parent_path)
       when is_binary(scope) do
    Path.schema_pointer_to_data_path(scope)
  end

  defp element_path_for(_uischema, parent_path), do: parent_path

  defp rule_state_for(%{"rule" => rule}, data, validator, validator_opts, cache)
       when is_map(rule) do
    effect = Map.get(rule, "effect")
    condition = Map.get(rule, "condition", %{})
    fail_when_undefined = Map.get(rule, "failWhenUndefined", false)

    {condition_true?, cache} =
      condition_true?(condition, data, validator, validator_opts, fail_when_undefined, cache)

    {apply_effect(effect, condition_true?), cache}
  end

  defp rule_state_for(_uischema, _data, _validator, _validator_opts, cache),
    do: {%{visible?: true, enabled?: true}, cache}

  defp condition_true?(
         %{"scope" => scope, "schema" => schema},
         data,
         validator,
         opts,
         fail_when_undefined,
         cache
       )
       when is_binary(scope) and is_map(schema) do
    path = Path.schema_pointer_to_data_path(scope)

    case Data.get(data, path) do
      {:ok, value} ->
        valid_schema?(schema, value, validator, opts, cache)

      {:error, _} ->
        {not fail_when_undefined, cache}
    end
  end

  defp condition_true?(%{"type" => type} = condition, _data, _validator, _opts, _fail, cache)
       when type in ["AND", "OR"] do
    Logger.warning("Unsupported composed rule condition",
      condition_type: type,
      condition: condition
    )

    {false, cache}
  end

  defp condition_true?(_condition, _data, _validator, _opts, _fail_when_undefined, cache),
    do: {false, cache}

  defp valid_schema?(_schema, _value, nil, _opts, cache), do: {false, cache}

  defp valid_schema?(schema, value, validator, opts, cache) when is_map(validator) do
    module = validator.module
    validator_opts = opts || []

    {compiled, cache} = fetch_compiled(schema, module, validator_opts, cache)

    result =
      case compiled do
        {:ok, compiled} -> module.validate(compiled, value, validator_opts) == []
        :error -> false
      end

    {result, cache}
  end

  defp fetch_compiled(schema, module, opts, cache) do
    key = {module, opts, schema}

    case cache do
      %{^key => compiled} ->
        {compiled, cache}

      _ ->
        compiled =
          case module.compile(schema, opts) do
            {:ok, compiled} -> {:ok, compiled}
            {:error, _} -> :error
          end

        {compiled, Map.put(cache, key, compiled)}
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
