defmodule JsonFormsLV.Engine do
  @moduledoc """
  Pure core engine functions.
  """

  alias JsonFormsLV.{Coercion, Data, Errors, Limits, Schema, State}

  @spec init(map(), map(), term(), map() | keyword()) :: {:ok, State.t()} | {:error, term()}
  def init(schema, uischema, data, opts) do
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
             {:ok, compiled} <- validator.compile(resolved_schema, validator_opts) do
          state = %State{
            schema: resolved_schema,
            uischema: uischema,
            data: data,
            opts: opts_with_limits,
            validation_mode: validation_mode,
            validator: %{module: validator, compiled: compiled},
            validator_opts: validator_opts
          }

          {:ok, validate_state(state)}
        end
    end
  end

  @spec update_data(State.t(), String.t(), term(), map()) :: {:ok, State.t()} | {:error, term()}
  def update_data(%State{} = state, data_path, raw_value, meta \\ %{}) do
    schema =
      case Schema.resolve_at_data_path(state.schema, data_path) do
        {:ok, fragment} -> fragment
        {:error, _} -> nil
      end

    case Coercion.coerce_with_raw(raw_value, schema, state.opts) do
      {:ok, coerced_value} ->
        with {:ok, updated_data} <- Data.put(state.data, data_path, coerced_value) do
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

          {:ok, validate_state(state)}
        end

      {:error, raw_value} ->
        previous_value =
          case Data.get(state.data, data_path) do
            {:ok, value} -> value
            {:error, _} -> nil
          end

        with {:ok, updated_data} <- Data.put(state.data, data_path, previous_value) do
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

          {:ok, validate_state(state)}
        end
    end
  end

  @spec touch(State.t(), String.t()) :: {:ok, State.t()} | {:error, term()}
  def touch(%State{} = state, data_path) when is_binary(data_path) do
    touched = MapSet.put(state.touched, data_path)
    {:ok, validate_state(%State{state | touched: touched})}
  end

  @spec set_additional_errors(State.t(), [map()]) :: {:ok, State.t()}
  def set_additional_errors(%State{} = state, additional_errors)
      when is_list(additional_errors) do
    state = %State{state | additional_errors: additional_errors}
    {:ok, validate_state(state)}
  end

  @spec set_validation_mode(State.t(), atom()) :: {:ok, State.t()}
  def set_validation_mode(%State{} = state, mode) when is_atom(mode) do
    state = %State{state | validation_mode: mode}
    {:ok, validate_state(state)}
  end

  @spec touch_all(State.t()) :: {:ok, State.t()}
  def touch_all(%State{} = state) do
    paths = collect_paths(state.data, "")
    touched = Enum.reduce(paths, state.touched, &MapSet.put(&2, &1))

    state = %State{state | touched: touched, submitted: true}
    {:ok, validate_state(state)}
  end

  @spec set_readonly(State.t(), boolean()) :: {:ok, State.t()}
  def set_readonly(%State{} = state, readonly) when is_boolean(readonly) do
    {:ok, %State{state | readonly: readonly}}
  end

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

    needs_compile? =
      schema != state.schema or state.validator == nil or
        state.validator.module != validator or state.validator_opts != validator_opts

    with {:ok, resolved_schema} <- resolver.resolve(schema, opts),
         {:ok, compiled} <-
           maybe_compile(needs_compile?, resolved_schema, validator, validator_opts, state) do
      state = %State{
        state
        | schema: resolved_schema,
          uischema: uischema,
          opts: opts,
          validator: %{module: validator, compiled: compiled},
          validator_opts: validator_opts
      }

      {:ok, validate_state(state)}
    end
  end

  def update_core(_state, updates), do: {:error, {:invalid_updates, updates}}

  @spec dispatch(State.t(), term()) :: {:ok, State.t()} | {:error, term()}
  def dispatch(%State{} = state, action) do
    case action do
      {:update_data, path, raw_value, meta} -> update_data(state, path, raw_value, meta)
      {:touch, path} -> touch(state, path)
      :touch_all -> touch_all(state)
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

  defp maybe_compile(false, _schema, _validator, _validator_opts, state),
    do: {:ok, state.validator.compiled}

  defp maybe_compile(true, schema, validator, validator_opts, _state),
    do: validator.compile(schema, validator_opts)

  defp validate_state(%State{} = state) do
    additional_errors = Errors.normalize_additional(state.additional_errors || [])

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

    errors = Errors.merge(validator_errors, additional_errors, state.opts)

    %State{state | errors: errors, additional_errors: additional_errors}
  end
end
