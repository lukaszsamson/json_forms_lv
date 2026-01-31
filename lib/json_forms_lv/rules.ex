defmodule JsonFormsLV.Rules do
  @moduledoc """
  Evaluate UISchema rules for visibility and enabled state.

  Rule state reflects element-level rules; parent visibility and enabled
  inheritance is applied at render time by the Phoenix components.
  """

  alias JsonFormsLV.{Data, Path}

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

  @spec evaluate(map(), term(), map() | nil, keyword(), map(), term()) :: {map(), map()}
  def evaluate(uischema, data, validator, validator_opts, cache, max_elements)
      when is_map(uischema) and is_map(cache) do
    max_elements = normalize_max_elements(max_elements)

    case max_elements do
      :infinity ->
        traverse(uischema, data, validator, validator_opts, "", [], %{}, cache)

      max when is_integer(max) and max > 0 ->
        {rule_state, cache, _count} =
          traverse_limited(uischema, data, validator, validator_opts, "", [], %{}, cache, max, 0)

        {rule_state, cache}

      _ ->
        {%{}, cache}
    end
  end

  @type rule_entry :: %{
          render_key: String.t(),
          condition: map(),
          effect: term(),
          fail_when_undefined: boolean(),
          scope_path: String.t() | nil
        }

  @spec index(map()) :: [rule_entry]
  def index(uischema) when is_map(uischema) do
    index(uischema, :infinity)
  end

  @spec index(map(), term()) :: [rule_entry]
  def index(uischema, max_elements) when is_map(uischema) do
    max_elements = normalize_max_elements(max_elements)

    {entries, _count} = collect_index(uischema, "", [], [], max_elements, 0)
    Enum.reverse(entries)
  end

  @spec evaluate_incremental(
          [rule_entry],
          map(),
          [String.t()],
          term(),
          map() | nil,
          keyword(),
          map()
        ) :: {map(), map()}
  def evaluate_incremental(
        rule_index,
        rule_state,
        changed_paths,
        data,
        validator,
        validator_opts,
        cache
      )
      when is_list(rule_index) and is_map(rule_state) and is_list(changed_paths) and
             is_map(cache) do
    entries = affected_entries(rule_index, changed_paths)

    Enum.reduce(entries, {rule_state, cache}, fn entry, {rule_state, cache} ->
      {flags, cache} = rule_state_for_entry(entry, data, validator, validator_opts, cache)
      {Map.put(rule_state, entry.render_key, flags), cache}
    end)
  end

  @spec affected_count([rule_entry], [String.t()]) :: non_neg_integer()
  def affected_count(rule_index, changed_paths)
      when is_list(rule_index) and is_list(changed_paths) do
    rule_index
    |> affected_entries(changed_paths)
    |> length()
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

  defp traverse_limited(
         uischema,
         data,
         validator,
         validator_opts,
         parent_path,
         element_path,
         acc,
         cache,
         max,
         count
       ) do
    if count >= max do
      {acc, cache, count}
    else
      path = element_path_for(uischema, parent_path)
      element_key = element_key(uischema, element_path)
      render_key = render_key(element_key, path)

      {rule_state, cache} = rule_state_for(uischema, data, validator, validator_opts, cache)
      acc = Map.put(acc, render_key, rule_state)
      count = count + 1

      case Map.get(uischema, "elements") do
        elements when is_list(elements) ->
          Enum.with_index(elements)
          |> Enum.reduce({acc, cache, count}, fn {child, index}, {acc, cache, count} ->
            traverse_limited(
              child,
              data,
              validator,
              validator_opts,
              path,
              element_path ++ [index],
              acc,
              cache,
              max,
              count
            )
          end)

        _ ->
          {acc, cache, count}
      end
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

  defp condition_true?(
         %{"type" => type, "conditions" => conditions},
         data,
         validator,
         opts,
         fail,
         cache
       )
       when type in ["AND", "OR"] and is_list(conditions) do
    initial = if type == "AND", do: true, else: false

    Enum.reduce_while(conditions, {initial, cache}, fn condition, {_result, cache} ->
      {result, cache} = condition_true?(condition, data, validator, opts, fail, cache)

      case type do
        "AND" ->
          if result, do: {:cont, {true, cache}}, else: {:halt, {false, cache}}

        "OR" ->
          if result, do: {:halt, {true, cache}}, else: {:cont, {false, cache}}
      end
    end)
  end

  defp condition_true?(_condition, _data, _validator, _opts, _fail_when_undefined, cache),
    do: {false, cache}

  defp valid_schema?(_schema, _value, nil, _opts, cache), do: {false, cache}

  defp valid_schema?(schema, value, %{module: module} = validator, opts, cache)
       when is_map(schema) do
    validator_opts = opts || []

    case schema do
      %{"$ref" => ref} when map_size(schema) == 1 and is_binary(ref) ->
        if String.starts_with?(ref, "#") and not is_nil(validator.compiled) and
             function_exported?(module, :validate_fragment, 4) do
          {module.validate_fragment(validator.compiled, ref, value, validator_opts) == [], cache}
        else
          valid_schema_via_compile(schema, value, module, validator_opts, cache)
        end

      _ ->
        valid_schema_via_compile(schema, value, module, validator_opts, cache)
    end
  end

  defp valid_schema_via_compile(schema, value, module, validator_opts, cache) do
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

  defp rule_state_for_entry(entry, data, validator, validator_opts, cache) do
    {condition_true?, cache} =
      condition_true?(
        entry.condition,
        data,
        validator,
        validator_opts,
        entry.fail_when_undefined,
        cache
      )

    {apply_effect(entry.effect, condition_true?), cache}
  end

  defp affected_entries(rule_index, changed_paths) do
    changed_paths
    |> Enum.filter(&is_binary/1)
    |> Enum.uniq()
    |> case do
      [] ->
        []

      paths ->
        Enum.filter(rule_index, fn entry ->
          case entry.scope_path do
            nil -> false
            scope_path -> Enum.any?(paths, &paths_related?(scope_path, &1))
          end
        end)
    end
  end

  defp paths_related?(path_a, path_b) when is_binary(path_a) and is_binary(path_b) do
    segments_a = Path.parse_data_path(path_a)
    segments_b = Path.parse_data_path(path_b)

    prefix?(segments_a, segments_b) or prefix?(segments_b, segments_a)
  end

  defp prefix?([], _segments), do: true
  defp prefix?(_segments, []), do: false

  defp prefix?([segment | rest], [segment | target_rest]), do: prefix?(rest, target_rest)
  defp prefix?(_segments, _target_segments), do: false

  defp collect_index(uischema, parent_path, element_path, acc, max, count) do
    if count >= max do
      {acc, count}
    else
      path = element_path_for(uischema, parent_path)
      element_key = element_key(uischema, element_path)
      render_key = render_key(element_key, path)

      count = count + 1

      acc =
        case Map.get(uischema, "rule") do
          rule when is_map(rule) ->
            [rule_entry(rule, render_key) | acc]

          _ ->
            acc
        end

      case Map.get(uischema, "elements") do
        elements when is_list(elements) ->
          Enum.with_index(elements)
          |> Enum.reduce({acc, count}, fn {child, index}, {acc, count} ->
            collect_index(child, path, element_path ++ [index], acc, max, count)
          end)

        _ ->
          {acc, count}
      end
    end
  end

  defp rule_entry(rule, render_key) do
    condition = Map.get(rule, "condition", %{})
    effect = Map.get(rule, "effect")
    fail_when_undefined = Map.get(rule, "failWhenUndefined", false)

    %{
      render_key: render_key,
      condition: condition,
      effect: effect,
      fail_when_undefined: fail_when_undefined,
      scope_path: scope_path(condition)
    }
  end

  defp scope_path(%{"scope" => scope}) when is_binary(scope) do
    Path.schema_pointer_to_data_path(scope)
  end

  defp scope_path(_condition), do: nil

  defp normalize_max_elements(:infinity), do: :infinity

  defp normalize_max_elements(max) when is_integer(max) and max > 0, do: max

  defp normalize_max_elements(_max), do: :infinity

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
