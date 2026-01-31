defmodule JsonFormsLV.Engine do
  @moduledoc """
  Pure core engine functions.
  """

  alias JsonFormsLV.{Coercion, Data, Errors, Limits, Path, Rules, Schema, State}

  @doc """
  Initialize a state from schema, uischema, and data.
  """
  @spec init(map(), map(), term(), map() | keyword()) :: {:ok, State.t()} | {:error, term()}
  def init(schema, uischema, data, opts) do
    started_at = System.monotonic_time()

    cond do
      not is_map(schema) ->
        {:error, {:invalid_schema, :expected_map}}

      not is_map(uischema) ->
        {:error, {:invalid_uischema, :expected_map}}

      true ->
        opts_map = normalize_opts(opts)
        opts_with_limits = Limits.with_defaults(opts_map)
        validation_mode = Map.get(opts_with_limits, :validation_mode, :validate_and_show)

        resolver =
          Map.get(opts_with_limits, :schema_resolver, JsonFormsLV.SchemaResolvers.Default)

        validator = Map.get(opts_with_limits, :validator, JsonFormsLV.Validators.JSV)
        validator_opts = Map.get(opts_with_limits, :validator_opts, [])

        with {:ok, resolved_schema} <- resolver.resolve(schema, opts_with_limits),
             {:ok, compiled} <- validator.compile(resolved_schema, validator_opts),
             data <- maybe_apply_defaults(data, resolved_schema, opts_with_limits),
             :ok <- ensure_data_size(data, opts_with_limits) do
          state = %State{
            schema: resolved_schema,
            uischema: uischema,
            data: data,
            opts: opts_with_limits,
            validation_mode: validation_mode,
            validator: %{module: validator, compiled: compiled},
            validator_opts: validator_opts
          }

          state = init_array_ids(state)
          state = validate_state(state, :all, true)

          emit_telemetry(:init, started_at, %{validation_mode: state.validation_mode})

          {:ok, state}
        end
    end
  end

  @doc """
  Update data at a path, applying coercion, rules, and validation.
  """
  @spec update_data(State.t(), String.t(), term(), map()) :: {:ok, State.t()} | {:error, term()}
  def update_data(%State{} = state, data_path, raw_value, meta \\ %{}) do
    started_at = System.monotonic_time()
    validate? = should_validate?(state, :change, meta)

    schema =
      case Schema.resolve_at_data_path(state.schema, data_path) do
        {:ok, fragment} -> fragment
        {:error, _} -> nil
      end

    case Coercion.coerce_with_raw(raw_value, schema, state.opts) do
      {:ok, coerced_value} ->
        with {:ok, updated_data} <-
               put_coerced_value(state.data, data_path, coerced_value, schema, raw_value),
             :ok <- ensure_data_size(updated_data, state.opts) do
          touched = maybe_touch(state.touched, data_path, meta)
          submitted = maybe_submit(state.submitted, meta)
          raw_inputs = Map.delete(state.raw_inputs, data_path)

          state =
            %State{
              state
              | data: updated_data,
                touched: touched,
                submitted: submitted,
                raw_inputs: raw_inputs
            }

          state = validate_state(state, [data_path], validate?)

          emit_telemetry(:update_data, started_at, %{path: data_path, result: :ok})

          {:ok, state}
        end

      {:error, raw_value} ->
        with {:ok, updated_data} <- put_invalid_value(state.data, data_path, schema),
             :ok <- ensure_data_size(updated_data, state.opts) do
          touched = maybe_touch(state.touched, data_path, meta)
          submitted = maybe_submit(state.submitted, meta)
          raw_inputs = Map.put(state.raw_inputs, data_path, raw_value)

          state =
            %State{
              state
              | data: updated_data,
                touched: touched,
                submitted: submitted,
                raw_inputs: raw_inputs
            }

          state = validate_state(state, [data_path], validate?)

          emit_telemetry(:update_data, started_at, %{path: data_path, result: :ok})

          {:ok, state}
        end
    end
  end

  @doc """
  Mark a path as touched for error gating.
  """
  @spec touch(State.t(), String.t()) :: {:ok, State.t()} | {:error, term()}
  def touch(%State{} = state, data_path) when is_binary(data_path) do
    touched = MapSet.put(state.touched, data_path)
    validate? = should_validate?(state, :blur, %{})
    {:ok, validate_state(%State{state | touched: touched}, [], validate?)}
  end

  @doc """
  Add a new item to an array at the given path.
  """
  @spec add_item(State.t(), String.t(), map() | keyword()) :: {:ok, State.t()} | {:error, term()}
  def add_item(%State{} = state, data_path, opts \\ %{}) do
    opts = normalize_opts(opts)
    validate? = should_validate?(state, :change, %{})

    with {:ok, array} <- get_array(state.data, data_path),
         {:ok, schema} <- Schema.resolve_at_data_path(state.schema, data_path) do
      index = normalize_index(Map.get(opts, :index) || Map.get(opts, "index"), length(array))
      item_schema = item_schema(schema, index)
      item = Map.get(opts, :item) || Map.get(opts, "item") || default_item(item_schema)
      item = maybe_apply_defaults(item, item_schema, state.opts)

      new_array = List.insert_at(array, index, item)

      with {:ok, updated_data} <- Data.put(state.data, data_path, new_array),
           :ok <- ensure_data_size(updated_data, state.opts) do
        ids = array_ids_for(state, data_path, array)
        new_id = ensure_item_id(item, ids, state.opts)
        new_ids = List.insert_at(ids, index, new_id)
        array_ids = Map.put(state.array_ids || %{}, data_path, new_ids)
        array_ids = remap_array_ids_on_insert(array_ids, data_path, index)

        state = %State{state | data: updated_data, array_ids: array_ids}
        {:ok, validate_state(state, [data_path], validate?)}
      end
    end
  end

  @doc """
  Remove an array item by index or stable id.
  """
  @spec remove_item(State.t(), String.t(), term()) :: {:ok, State.t()} | {:error, term()}
  def remove_item(%State{} = state, data_path, index_or_id) do
    validate? = should_validate?(state, :change, %{})

    with {:ok, array} <- get_array(state.data, data_path),
         {:ok, index} <- resolve_index(state, data_path, array, index_or_id) do
      new_array = List.delete_at(array, index)

      with {:ok, updated_data} <- Data.put(state.data, data_path, new_array),
           :ok <- ensure_data_size(updated_data, state.opts) do
        ids = array_ids_for(state, data_path, array)
        new_ids = List.delete_at(ids, index)
        array_ids = Map.put(state.array_ids || %{}, data_path, new_ids)
        array_ids = remap_array_ids_on_remove(array_ids, data_path, index)
        state = %State{state | data: updated_data, array_ids: array_ids}
        state = prune_array_state(state, data_path)
        {:ok, validate_state(state, [data_path], validate?)}
      end
    end
  end

  @doc """
  Move an array item from one index to another.
  """
  @spec move_item(State.t(), String.t(), term(), term()) :: {:ok, State.t()} | {:error, term()}
  def move_item(%State{} = state, data_path, from, to) do
    validate? = should_validate?(state, :change, %{})

    with {:ok, array} <- get_array(state.data, data_path),
         {:ok, from_index} <- normalize_index(from),
         {:ok, to_index} <- normalize_index(to),
         true <- from_index >= 0 and from_index < length(array),
         true <- to_index >= 0 and to_index < length(array) do
      new_array = move_list_item(array, from_index, to_index)

      with {:ok, updated_data} <- Data.put(state.data, data_path, new_array),
           :ok <- ensure_data_size(updated_data, state.opts) do
        ids = array_ids_for(state, data_path, array)
        new_ids = move_list_item(ids, from_index, to_index)
        array_ids = Map.put(state.array_ids || %{}, data_path, new_ids)
        array_ids = remap_array_ids_on_move(array_ids, data_path, from_index, to_index)
        state = %State{state | data: updated_data, array_ids: array_ids}
        state = prune_array_state(state, data_path)
        {:ok, validate_state(state, [data_path], validate?)}
      end
    else
      false -> {:error, {:invalid_index, data_path}}
      {:error, _} = error -> error
    end
  end

  @doc """
  Replace additional errors and revalidate.
  """
  @spec set_additional_errors(State.t(), [map()]) :: {:ok, State.t()}
  def set_additional_errors(%State{} = state, additional_errors)
      when is_list(additional_errors) do
    state = %State{state | additional_errors: additional_errors}
    {:ok, validate_state(state, [], true)}
  end

  @doc """
  Update validation mode and revalidate.
  """
  @spec set_validation_mode(State.t(), atom()) :: {:ok, State.t()}
  def set_validation_mode(%State{} = state, mode) when is_atom(mode) do
    state = %State{state | validation_mode: mode}
    {:ok, validate_state(state, [], true)}
  end

  @doc """
  Mark all current paths as touched and set submitted.
  """
  @spec touch_all(State.t()) :: {:ok, State.t()}
  def touch_all(%State{} = state) do
    paths = collect_paths(state.data, "")
    touched = Enum.reduce(paths, state.touched, &MapSet.put(&2, &1))

    state = %State{state | touched: touched, submitted: true}
    validate? = should_validate?(state, :submit, %{})
    {:ok, validate_state(state, [], validate?)}
  end

  @doc """
  Set global readonly state.
  """
  @spec set_readonly(State.t(), boolean()) :: {:ok, State.t()}
  def set_readonly(%State{} = state, readonly) when is_boolean(readonly) do
    {:ok, %State{state | readonly: readonly}}
  end

  @doc """
  Update core schema/uischema/options and revalidate.
  """
  @spec update_core(State.t(), map()) :: {:ok, State.t()} | {:error, term()}
  def update_core(%State{} = state, updates) when is_map(updates) do
    schema = Map.get(updates, :schema) || Map.get(updates, "schema") || state.schema
    uischema = Map.get(updates, :uischema) || Map.get(updates, "uischema") || state.uischema
    opts_update = Map.get(updates, :opts) || Map.get(updates, "opts")

    opts =
      if is_map(opts_update) do
        state.opts
        |> Map.merge(opts_update)
        |> Limits.with_defaults()
      else
        state.opts
      end

    validator = Map.get(opts, :validator, JsonFormsLV.Validators.JSV)
    validator_opts = Map.get(opts, :validator_opts, [])
    resolver = Map.get(opts, :schema_resolver, JsonFormsLV.SchemaResolvers.Default)

    validator_changed? =
      state.validator == nil or state.validator.module != validator or
        state.validator_opts != validator_opts

    uischema_changed? = uischema != state.uischema
    needs_compile? = schema != state.schema or validator_changed?

    rule_schema_cache =
      if uischema_changed? or validator_changed? do
        %{}
      else
        state.rule_schema_cache || %{}
      end

    rule_index =
      if uischema_changed? do
        nil
      else
        state.rule_index
      end

    with {:ok, resolved_schema} <- resolver.resolve(schema, opts),
         {:ok, compiled} <-
           maybe_compile(needs_compile?, resolved_schema, validator, validator_opts, state) do
      state = %State{
        state
        | schema: resolved_schema,
          uischema: uischema,
          opts: opts,
          validator: %{module: validator, compiled: compiled},
          validator_opts: validator_opts,
          rule_schema_cache: rule_schema_cache,
          rule_index: rule_index
      }

      {:ok, validate_state(state, :all, true)}
    end
  end

  def update_core(_state, updates), do: {:error, {:invalid_updates, updates}}

  @doc """
  Dispatch a reducer-style action.
  """
  @spec dispatch(State.t(), term()) :: {:ok, State.t()} | {:error, term()}
  def dispatch(%State{} = state, action) do
    case action do
      {:update_data, path, raw_value, meta} -> update_data(state, path, raw_value, meta)
      {:touch, path} -> touch(state, path)
      :touch_all -> touch_all(state)
      {:add_item, path, opts} -> add_item(state, path, opts)
      {:remove_item, path, index_or_id} -> remove_item(state, path, index_or_id)
      {:move_item, path, from, to} -> move_item(state, path, from, to)
      {:set_additional_errors, errors} -> set_additional_errors(state, errors)
      {:set_validation_mode, mode} -> set_validation_mode(state, mode)
      {:set_readonly, readonly} -> set_readonly(state, readonly)
      {:update_core, updates} -> update_core(state, updates)
      _ -> {:error, {:unsupported_action, action}}
    end
  end

  defp normalize_opts(nil), do: %{}
  defp normalize_opts(opts) when is_map(opts), do: opts
  defp normalize_opts(opts) when is_list(opts), do: Map.new(opts)

  defp maybe_touch(touched, data_path, meta) when is_map(meta) do
    touch? =
      Map.get(meta, :touch) || Map.get(meta, "touch") || Map.get(meta, :touch?) ||
        Map.get(meta, "touch?")

    if touch? do
      MapSet.put(touched, data_path)
    else
      touched
    end
  end

  defp maybe_touch(touched, _data_path, _meta), do: touched

  defp maybe_submit(submitted, meta) when is_map(meta) do
    submit? =
      Map.get(meta, :submit) || Map.get(meta, "submit") || Map.get(meta, :submitted) ||
        Map.get(meta, "submitted")

    if submit? do
      true
    else
      submitted
    end
  end

  defp maybe_submit(submitted, _meta), do: submitted

  defp put_coerced_value(data, path, value, schema, raw_value) do
    if value == nil and raw_value in ["", nil] and not nullable_schema?(schema) do
      case Data.delete(data, path) do
        {:ok, updated} -> {:ok, updated}
        {:error, _} -> Data.put(data, path, nil)
      end
    else
      Data.put(data, path, value)
    end
  end

  defp put_invalid_value(data, path, _schema) do
    Data.put(data, path, nil)
  end

  defp nullable_schema?(%{"type" => "null"}), do: true

  defp nullable_schema?(%{"type" => types}) when is_list(types) do
    "null" in types
  end

  defp nullable_schema?(_schema), do: false

  defp should_validate?(%State{} = state, event, meta) when is_atom(event) do
    validate_on =
      Map.get(state.opts || %{}, :validate_on) || Map.get(state.opts || %{}, "validate_on") ||
        :change

    if validate_override?(meta) do
      true
    else
      case validate_on do
        :change -> event == :change
        :blur -> event in [:blur, :submit]
        :submit -> event == :submit
        _ -> true
      end
    end
  end

  defp should_validate?(_state, _event, _meta), do: true

  defp validate_override?(meta) when is_map(meta) do
    Map.get(meta, :validate) == true or Map.get(meta, "validate") == true or
      Map.get(meta, :validate?) == true or Map.get(meta, "validate?") == true
  end

  defp validate_override?(_meta), do: false

  defp collect_paths(map, prefix) when is_map(map) do
    Enum.flat_map(map, fn {key, value} ->
      path = if prefix == "", do: key, else: "#{prefix}.#{key}"
      [path | collect_paths(value, path)]
    end)
  end

  defp collect_paths(list, prefix) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.flat_map(fn {value, index} ->
      path = if prefix == "", do: Integer.to_string(index), else: "#{prefix}.#{index}"
      [path | collect_paths(value, path)]
    end)
  end

  defp collect_paths(_value, _prefix), do: []

  defp maybe_apply_defaults(data, schema, opts) do
    apply_defaults? = Map.get(opts || %{}, :apply_defaults, false)
    apply_defaults? = apply_defaults? || Map.get(opts || %{}, "apply_defaults") == true

    if apply_defaults? do
      apply_defaults(data, schema)
    else
      data
    end
  end

  defp apply_defaults(data, schema) when is_map(schema) do
    data =
      cond do
        data != nil ->
          data

        Map.has_key?(schema, "default") ->
          Map.get(schema, "default")

        object_schema?(schema) ->
          %{}

        true ->
          data
      end

    cond do
      is_map(data) ->
        apply_defaults_object(data, schema)

      is_list(data) ->
        apply_defaults_array(data, schema)

      true ->
        data
    end
  end

  defp apply_defaults(data, _schema), do: data

  defp apply_defaults_object(data, schema) do
    props = Map.get(schema, "properties", %{})

    Enum.reduce(props, data, fn {key, prop_schema}, acc ->
      if Map.has_key?(acc, key) do
        Map.update!(acc, key, &apply_defaults(&1, prop_schema))
      else
        case Map.fetch(prop_schema || %{}, "default") do
          {:ok, default} -> Map.put(acc, key, default)
          :error -> acc
        end
      end
    end)
  end

  defp apply_defaults_array(data, %{"items" => items}) when is_list(items) do
    Enum.with_index(data)
    |> Enum.map(fn {item, index} ->
      schema = Enum.at(items, index)
      apply_defaults(item, schema || %{})
    end)
  end

  defp apply_defaults_array(data, %{"items" => items}) when is_map(items) do
    Enum.map(data, &apply_defaults(&1, items))
  end

  defp apply_defaults_array(data, _schema), do: data

  defp maybe_compile(false, _schema, _validator, _validator_opts, state),
    do: {:ok, state.validator.compiled}

  defp maybe_compile(true, schema, validator, validator_opts, _state),
    do: validator.compile(schema, validator_opts)

  defp ensure_data_size(data, opts) do
    max_bytes =
      Map.get(opts || %{}, :max_data_bytes) || Map.get(opts || %{}, "max_data_bytes") ||
        Limits.defaults().max_data_bytes

    cond do
      max_bytes in [nil, :infinity] ->
        :ok

      is_integer(max_bytes) and max_bytes > 0 ->
        size = byte_size(:erlang.term_to_binary(data))

        if size <= max_bytes do
          :ok
        else
          {:error, {:max_data_bytes_exceeded, size, max_bytes}}
        end

      true ->
        :ok
    end
  end

  defp get_array(data, path) do
    case Data.get(data, path) do
      {:ok, nil} -> {:ok, []}
      {:ok, array} when is_list(array) -> {:ok, array}
      {:ok, _value} -> {:error, {:invalid_path, path}}
      {:error, _} -> {:ok, []}
    end
  end

  defp normalize_index(nil, default), do: default

  defp normalize_index(value, default) do
    case normalize_index(value) do
      {:ok, index} -> index
      {:error, _} -> default
    end
  end

  defp normalize_index(value) when is_integer(value), do: {:ok, value}

  defp normalize_index(value) when is_binary(value) do
    case Integer.parse(value) do
      {index, ""} -> {:ok, index}
      _ -> {:error, :invalid_index}
    end
  end

  defp normalize_index(_value), do: {:error, :invalid_index}

  defp resolve_index(state, path, array, index_or_id) do
    case normalize_index(index_or_id) do
      {:ok, index} ->
        if index >= 0 and index < length(array) do
          {:ok, index}
        else
          {:error, {:invalid_index, path}}
        end

      {:error, _} ->
        ids = array_ids_for(state, path, array)
        id = to_string(index_or_id)

        case Enum.find_index(ids, &(&1 == id)) do
          nil -> {:error, {:invalid_index, path}}
          index -> {:ok, index}
        end
    end
  end

  defp item_schema(%{"items" => items}, index) when is_list(items) and is_integer(index) do
    if index >= 0 and index < length(items) do
      Enum.at(items, index)
    else
      nil
    end
  end

  defp item_schema(%{"items" => items}, _index) when is_map(items), do: items
  defp item_schema(_schema, _index), do: nil

  defp default_item(%{"default" => default}) when not is_nil(default), do: default
  defp default_item(%{"type" => "object"}), do: %{}

  defp default_item(%{"type" => types}) when is_list(types),
    do: default_item(type_from_union(types))

  defp default_item(%{"type" => "string"}), do: ""
  defp default_item(_schema), do: nil

  defp type_from_union(types) do
    if "null" in types do
      %{"type" => Enum.find(types, &(&1 != "null"))}
    else
      %{"type" => List.first(types)}
    end
  end

  defp array_ids_for(state, path, array) do
    ids = Map.get(state.array_ids || %{}, path, [])

    if length(ids) == length(array) do
      ids
    else
      derive_array_ids(array, state.opts)
    end
  end

  defp derive_array_ids(array, opts) do
    id_field = Map.get(opts || %{}, :array_id_field, "id")

    {ids, _} =
      Enum.reduce(array, {[], MapSet.new()}, fn item, {acc, seen} ->
        id = item_id(item, id_field)

        id =
          cond do
            is_binary(id) and not MapSet.member?(seen, id) -> id
            true -> generate_id(seen)
          end

        {[id | acc], MapSet.put(seen, id)}
      end)

    Enum.reverse(ids)
  end

  defp ensure_item_id(item, existing_ids, opts) do
    id_field = Map.get(opts || %{}, :array_id_field, "id")
    id = item_id(item, id_field)

    cond do
      is_binary(id) and id not in existing_ids -> id
      true -> generate_id(MapSet.new(existing_ids))
    end
  end

  defp item_id(item, id_field) when is_map(item) do
    case Map.get(item, id_field) do
      nil -> nil
      value -> to_string(value)
    end
  end

  defp item_id(_item, _id_field), do: nil

  defp generate_id(seen) do
    id = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)

    if MapSet.member?(seen, id) do
      generate_id(seen)
    else
      id
    end
  end

  defp move_list_item(list, from, to) when from == to, do: list

  defp move_list_item(list, from, to) do
    {item, list} = List.pop_at(list, from)
    List.insert_at(list, to, item)
  end

  defp prune_array_state(%State{} = state, path) do
    prefix = if path == "", do: "", else: path <> "."

    touched =
      state.touched
      |> Enum.reject(&(&1 == path or String.starts_with?(&1, prefix)))
      |> MapSet.new()

    raw_inputs =
      state.raw_inputs
      |> Enum.reject(fn {key, _val} -> key == path or String.starts_with?(key, prefix) end)
      |> Map.new()

    %State{state | touched: touched, raw_inputs: raw_inputs}
  end

  defp remap_array_ids_on_insert(array_ids, path, index) do
    remap_array_ids(array_ids, path, fn entry_index ->
      if entry_index >= index do
        entry_index + 1
      else
        entry_index
      end
    end)
  end

  defp remap_array_ids_on_remove(array_ids, path, index) do
    remap_array_ids(array_ids, path, fn entry_index ->
      cond do
        entry_index == index -> :drop
        entry_index > index -> entry_index - 1
        true -> entry_index
      end
    end)
  end

  defp remap_array_ids_on_move(array_ids, path, from_index, to_index) do
    remap_array_ids(array_ids, path, fn entry_index ->
      remap_index(entry_index, from_index, to_index)
    end)
  end

  defp remap_array_ids(array_ids, path, remap_fun) when is_map(array_ids) do
    prefix = if path == "", do: "", else: path <> "."

    Enum.reduce(array_ids, %{}, fn {key, ids}, acc ->
      cond do
        key == path ->
          Map.put(acc, key, ids)

        String.starts_with?(key, prefix) ->
          rest = String.replace_prefix(key, prefix, "")

          case split_index_segment(rest) do
            {:ok, index, tail} ->
              case remap_fun.(index) do
                :drop -> acc
                new_index -> Map.put(acc, prefix <> Integer.to_string(new_index) <> tail, ids)
              end

            :error ->
              Map.put(acc, key, ids)
          end

        true ->
          Map.put(acc, key, ids)
      end
    end)
  end

  defp remap_array_ids(array_ids, _path, _remap_fun), do: array_ids

  defp split_index_segment(""), do: :error

  defp split_index_segment(rest) do
    case String.split(rest, ".", parts: 2) do
      [segment] -> parse_index_segment(segment, "")
      [segment, tail] -> parse_index_segment(segment, "." <> tail)
      _ -> :error
    end
  end

  defp parse_index_segment(segment, tail) do
    case Integer.parse(segment) do
      {index, ""} -> {:ok, index, tail}
      _ -> :error
    end
  end

  defp remap_index(index, from, to) when from == to, do: index

  defp remap_index(index, from, to) when from < to do
    cond do
      index == from -> to
      index > from and index <= to -> index - 1
      true -> index
    end
  end

  defp remap_index(index, from, to) when from > to do
    cond do
      index == from -> to
      index >= to and index < from -> index + 1
      true -> index
    end
  end

  defp init_array_ids(%State{} = state) do
    array_ids =
      collect_array_ids(state.schema, state.data, state.opts, "", state.array_ids || %{})

    %State{state | array_ids: array_ids}
  end

  defp collect_array_ids(schema, data, opts, path, acc) when is_map(schema) and is_list(data) do
    if array_schema?(schema) do
      existing_ids = Map.get(acc, path)

      ids =
        if is_list(existing_ids) and length(existing_ids) == length(data) do
          existing_ids
        else
          derive_array_ids(data, opts)
        end

      acc = Map.put(acc, path, ids)

      Enum.reduce(Enum.with_index(data), acc, fn {item, index}, acc ->
        item_schema = item_schema(schema, index)
        item_path = Path.join(path, Integer.to_string(index))
        collect_array_ids(item_schema || %{}, item, opts, item_path, acc)
      end)
    else
      acc
    end
  end

  defp collect_array_ids(schema, data, opts, path, acc) when is_map(schema) and is_map(data) do
    if object_schema?(schema) do
      props = Map.get(schema, "properties", %{})

      Enum.reduce(props, acc, fn {key, prop_schema}, acc ->
        value = Map.get(data, key)
        prop_path = Path.join(path, key)
        collect_array_ids(prop_schema || %{}, value, opts, prop_path, acc)
      end)
    else
      acc
    end
  end

  defp collect_array_ids(_schema, _data, _opts, _path, acc), do: acc

  defp array_schema?(%{"type" => "array"}), do: true
  defp array_schema?(%{"items" => items}) when is_map(items) or is_list(items), do: true
  defp array_schema?(_schema), do: false

  defp object_schema?(%{"type" => "object"}), do: true
  defp object_schema?(%{"properties" => props}) when is_map(props), do: true
  defp object_schema?(_schema), do: false

  defp validate_state(%State{} = state, changed_paths, validate?) do
    started_at = System.monotonic_time()

    {rule_state, rule_schema_cache, rule_index, rule_stats} =
      evaluate_rules(state, changed_paths)

    additional_errors = Errors.normalize_additional(state.additional_errors || [])

    {errors, additional_errors} =
      if validate? do
        validator_errors =
          cond do
            state.validation_mode == :no_validation ->
              []

            state.validator == nil ->
              []

            true ->
              state.validator.module.validate(
                state.validator.compiled,
                state.data,
                state.validator_opts
              )
          end

        {Errors.merge(validator_errors, additional_errors, state.opts), additional_errors}
      else
        {state.errors || [], additional_errors}
      end

    state = %State{
      state
      | errors: errors,
        additional_errors: additional_errors,
        rule_state: rule_state,
        rule_schema_cache: rule_schema_cache,
        rule_index: rule_index
    }

    emit_telemetry(:validate, started_at, Map.merge(%{error_count: length(errors)}, rule_stats))

    state
  end

  defp evaluate_rules(%State{} = state, changed_paths) do
    rule_schema_cache = state.rule_schema_cache || %{}
    rule_index_missing? = state.rule_index == nil

    max_elements =
      Map.get(state.opts || %{}, :max_elements) || Map.get(state.opts || %{}, "max_elements") ||
        Limits.defaults().max_elements

    rule_index = state.rule_index || Rules.index(state.uischema, max_elements)
    rules_total = length(rule_index)
    changed_paths_count = if is_list(changed_paths), do: length(changed_paths), else: 0

    cond do
      rule_index_missing? ->
        {rule_state, rule_schema_cache} =
          Rules.evaluate(
            state.uischema,
            state.data,
            state.validator,
            state.validator_opts,
            rule_schema_cache,
            max_elements
          )

        rule_stats = %{
          rules_total: rules_total,
          rules_evaluated: rules_total,
          rules_incremental: false,
          rules_changed_paths: changed_paths_count
        }

        {rule_state, rule_schema_cache, rule_index, rule_stats}

      changed_paths == :all ->
        {rule_state, rule_schema_cache} =
          Rules.evaluate(
            state.uischema,
            state.data,
            state.validator,
            state.validator_opts,
            rule_schema_cache,
            max_elements
          )

        rule_stats = %{
          rules_total: rules_total,
          rules_evaluated: rules_total,
          rules_incremental: false,
          rules_changed_paths: changed_paths_count
        }

        {rule_state, rule_schema_cache, rule_index, rule_stats}

      is_list(changed_paths) and changed_paths == [] ->
        rule_stats = %{
          rules_total: rules_total,
          rules_evaluated: 0,
          rules_incremental: true,
          rules_changed_paths: 0
        }

        {state.rule_state || %{}, rule_schema_cache, rule_index, rule_stats}

      is_list(changed_paths) ->
        rules_evaluated = Rules.affected_count(rule_index, changed_paths)

        {rule_state, rule_schema_cache} =
          Rules.evaluate_incremental(
            rule_index,
            state.rule_state || %{},
            changed_paths,
            state.data,
            state.validator,
            state.validator_opts,
            rule_schema_cache
          )

        rule_stats = %{
          rules_total: rules_total,
          rules_evaluated: rules_evaluated,
          rules_incremental: true,
          rules_changed_paths: changed_paths_count
        }

        {rule_state, rule_schema_cache, rule_index, rule_stats}

      true ->
        {rule_state, rule_schema_cache} =
          Rules.evaluate(
            state.uischema,
            state.data,
            state.validator,
            state.validator_opts,
            rule_schema_cache,
            max_elements
          )

        rule_stats = %{
          rules_total: rules_total,
          rules_evaluated: rules_total,
          rules_incremental: false,
          rules_changed_paths: changed_paths_count
        }

        {rule_state, rule_schema_cache, rule_index, rule_stats}
    end
  end

  defp emit_telemetry(event, started_at, metadata) when is_atom(event) do
    duration = System.monotonic_time() - started_at

    :telemetry.execute(
      [:json_forms_lv, event],
      %{duration: duration},
      metadata
    )
  end
end
