defmodule JsonFormsLV.Schema do
  @moduledoc """
  Helpers for resolving schema fragments.
  """

  alias JsonFormsLV.Path

  @spec resolve_pointer(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def resolve_pointer(schema, pointer) when is_map(schema) and pointer in ["", "#"] do
    {:ok, schema}
  end

  def resolve_pointer(schema, pointer) when is_map(schema) and is_binary(pointer) do
    pointer
    |> normalize_pointer()
    |> pointer_segments()
    |> do_resolve_pointer(schema, pointer)
  end

  @spec resolve_at_data_path(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def resolve_at_data_path(schema, data_path) when is_map(schema) and data_path == "" do
    {:ok, schema}
  end

  def resolve_at_data_path(schema, data_path) when is_map(schema) and is_binary(data_path) do
    segments = Path.parse_data_path(data_path)
    do_resolve_at_path(schema, segments, data_path)
  end

  @spec resolve_at_data_path(map(), String.t(), term(), map() | nil, list()) ::
          {:ok, map()} | {:error, term()}
  def resolve_at_data_path(schema, data_path, data, validator, validator_opts)
      when is_map(schema) and data_path == "" do
    {:ok, apply_conditionals(schema, data, validator, validator_opts)}
  end

  def resolve_at_data_path(schema, data_path, data, validator, validator_opts)
      when is_map(schema) and is_binary(data_path) do
    segments = Path.parse_data_path(data_path)
    do_resolve_at_path(schema, segments, data_path, data, validator, validator_opts)
  end

  defp do_resolve_pointer([], current, _pointer), do: {:ok, current}

  defp do_resolve_pointer(segments, current, pointer) do
    Enum.reduce_while(segments, {:ok, current}, fn segment, {:ok, acc} ->
      case fetch_pointer_segment(acc, segment) do
        {:ok, next} -> {:cont, {:ok, next}}
        :error -> {:halt, {:error, {:pointer_not_found, pointer}}}
      end
    end)
  end

  defp fetch_pointer_segment(map, segment) when is_map(map) do
    Map.fetch(map, segment)
  end

  defp fetch_pointer_segment(list, segment) when is_list(list) do
    with {index, ""} <- Integer.parse(segment),
         true <- index >= 0 and index < length(list) do
      {:ok, Enum.at(list, index)}
    else
      _ -> :error
    end
  end

  defp fetch_pointer_segment(_other, _segment), do: :error

  defp do_resolve_at_path(current, [], _data_path), do: {:ok, current}

  defp do_resolve_at_path(%{"properties" => props} = _current, [segment | rest], data_path)
       when is_binary(segment) and is_map(props) do
    case Map.fetch(props, segment) do
      {:ok, next} -> do_resolve_at_path(next, rest, data_path)
      :error -> {:error, {:path_not_found, data_path}}
    end
  end

  defp do_resolve_at_path(%{"items" => items} = _current, [segment | rest], data_path)
       when is_integer(segment) do
    case items do
      list when is_list(list) ->
        if segment >= 0 and segment < length(list) do
          do_resolve_at_path(Enum.at(list, segment), rest, data_path)
        else
          {:error, {:path_not_found, data_path}}
        end

      map when is_map(map) ->
        do_resolve_at_path(map, rest, data_path)

      _ ->
        {:error, {:path_not_found, data_path}}
    end
  end

  defp do_resolve_at_path(_current, _segments, data_path) do
    {:error, {:path_not_found, data_path}}
  end

  defp do_resolve_at_path(current, [], _data_path, data, validator, validator_opts) do
    {:ok, apply_conditionals(current, data, validator, validator_opts)}
  end

  defp do_resolve_at_path(
         %{"properties" => props} = current,
         [segment | rest],
         data_path,
         data,
         validator,
         validator_opts
       )
       when is_binary(segment) and is_map(props) do
    current = apply_conditionals(current, data, validator, validator_opts)

    case Map.fetch(current["properties"] || %{}, segment) do
      {:ok, next} ->
        next_data = if is_map(data), do: Map.get(data, segment), else: nil
        do_resolve_at_path(next, rest, data_path, next_data, validator, validator_opts)

      :error ->
        {:error, {:path_not_found, data_path}}
    end
  end

  defp do_resolve_at_path(
         %{"items" => _items} = current,
         [segment | rest],
         data_path,
         data,
         validator,
         validator_opts
       )
       when is_integer(segment) do
    current = apply_conditionals(current, data, validator, validator_opts)
    items = current["items"]

    case items do
      list when is_list(list) ->
        if segment >= 0 and segment < length(list) do
          next_data = if is_list(data), do: Enum.at(data, segment), else: nil

          do_resolve_at_path(
            Enum.at(list, segment),
            rest,
            data_path,
            next_data,
            validator,
            validator_opts
          )
        else
          {:error, {:path_not_found, data_path}}
        end

      map when is_map(map) ->
        next_data = if is_list(data), do: Enum.at(data, segment), else: nil
        do_resolve_at_path(map, rest, data_path, next_data, validator, validator_opts)

      _ ->
        {:error, {:path_not_found, data_path}}
    end
  end

  defp do_resolve_at_path(_current, _segments, data_path, _data, _validator, _validator_opts) do
    {:error, {:path_not_found, data_path}}
  end

  defp normalize_pointer(pointer) do
    String.replace_prefix(pointer, "#", "")
  end

  defp pointer_segments(""), do: []

  defp pointer_segments(pointer) do
    pointer
    |> String.trim_leading("/")
    |> String.split("/", trim: true)
    |> Enum.map(&decode_pointer_segment/1)
  end

  defp decode_pointer_segment(segment) do
    segment
    |> String.replace("~1", "/")
    |> String.replace("~0", "~")
  end

  defp apply_conditionals(schema, data, validator, validator_opts) when is_map(schema) do
    if_schema = Map.get(schema, "if")

    if is_map(if_schema) do
      base = Map.drop(schema, ["if", "then", "else"])
      then_schema = Map.get(schema, "then")
      else_schema = Map.get(schema, "else")

      if schema_valid?(if_schema, data, validator, validator_opts) do
        merge_schema(base, then_schema)
      else
        merge_schema(base, else_schema)
      end
    else
      schema
    end
  end

  defp apply_conditionals(schema, _data, _validator, _validator_opts), do: schema

  defp merge_schema(base, nil), do: base

  defp merge_schema(base, branch) when is_map(base) and is_map(branch) do
    Map.merge(base, branch, fn key, left, right ->
      cond do
        key == "required" and is_list(left) and is_list(right) ->
          Enum.uniq(left ++ right)

        is_map(left) and is_map(right) ->
          merge_schema(left, right)

        true ->
          right
      end
    end)
  end

  defp merge_schema(base, _branch), do: base

  defp schema_valid?(_schema, _data, nil, _opts), do: false

  defp schema_valid?(schema, data, %{module: module} = validator, opts) when is_map(schema) do
    validator_opts = opts || []

    case schema do
      %{"$ref" => ref} when map_size(schema) == 1 and is_binary(ref) ->
        if String.starts_with?(ref, "#") and not is_nil(validator.compiled) and
             validate_fragment_supported?(module) do
          module.validate_fragment(validator.compiled, ref, data, validator_opts) == []
        else
          schema_valid_via_compile(schema, data, module, validator_opts)
        end

      _ ->
        schema_valid_via_compile(schema, data, module, validator_opts)
    end
  end

  defp schema_valid?(_schema, _data, _validator, _opts), do: false

  defp schema_valid_via_compile(schema, data, module, validator_opts) do
    case module.compile(schema, validator_opts) do
      {:ok, compiled} -> module.validate(compiled, data, validator_opts) == []
      {:error, _} -> false
    end
  end

  defp validate_fragment_supported?(module) when is_atom(module) do
    case Code.ensure_loaded(module) do
      {:module, _} -> function_exported?(module, :validate_fragment, 4)
      _ -> false
    end
  end
end
