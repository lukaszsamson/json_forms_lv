defmodule JsonFormsLV.FormGroup do
  @moduledoc """
  Manage multiple form states with shared data.
  """

  alias JsonFormsLV.{Engine, Path, Schema, State}

  @type form_config :: %{
          required(:id) => term(),
          required(:schema) => map(),
          optional(:uischema) => map(),
          optional(:data) => term(),
          optional(:opts) => map() | keyword()
        }

  @type t :: %__MODULE__{
          data: term(),
          forms: %{optional(term()) => State.t()},
          opts: map()
        }

  defstruct data: %{}, forms: %{}, opts: %{}

  @spec init([form_config()], map() | keyword()) :: {:ok, t()} | {:error, term()}
  def init(forms, opts \\ %{}) when is_list(forms) do
    opts = normalize_opts(opts)
    base_data = Map.get(opts, :data) || Map.get(opts, "data")
    data = if is_nil(base_data), do: merge_form_data(forms), else: base_data
    group_opts = Map.get(opts, :engine_opts) || Map.get(opts, "engine_opts") || %{}

    forms_result =
      Enum.reduce_while(forms, {:ok, %{}}, fn form, {:ok, acc} ->
        id = form_id(form)
        schema = Map.get(form, :schema) || Map.get(form, "schema")
        uischema = Map.get(form, :uischema) || Map.get(form, "uischema") || %{}
        form_opts = Map.get(form, :opts) || Map.get(form, "opts") || %{}
        engine_opts = Map.merge(group_opts, normalize_opts(form_opts))

        case Engine.init(schema, uischema, data, engine_opts) do
          {:ok, state} -> {:cont, {:ok, Map.put(acc, id, state)}}
          {:error, reason} -> {:halt, {:error, {id, reason}}}
        end
      end)

    case forms_result do
      {:ok, forms_map} -> {:ok, %__MODULE__{data: data, forms: forms_map, opts: opts}}
      {:error, _} = error -> error
    end
  end

  @spec state(t(), term()) :: State.t() | nil
  def state(%__MODULE__{} = group, id) do
    Map.get(group.forms, id)
  end

  @spec dispatch(t(), term(), term()) :: {:ok, t()} | {:error, term()}
  def dispatch(%__MODULE__{} = group, id, action) do
    case Map.get(group.forms, id) do
      %State{} = state ->
        with {:ok, updated_state} <- Engine.dispatch(state, action) do
          changed_paths = action_changed_paths(action, updated_state)

          if is_list(changed_paths) do
            propagate_data(group, id, updated_state, changed_paths)
          else
            forms = Map.put(group.forms, id, updated_state)
            {:ok, %__MODULE__{group | data: updated_state.data, forms: forms}}
          end
        end

      nil ->
        {:error, {:unknown_form, id}}
    end
  end

  defp propagate_data(%__MODULE__{} = group, id, updated_state, changed_paths) do
    new_data = updated_state.data

    forms_result =
      Enum.reduce_while(group.forms, {:ok, %{}}, fn {form_id, form_state}, {:ok, acc} ->
        if form_id == id do
          {:cont, {:ok, Map.put(acc, form_id, updated_state)}}
        else
          case Engine.apply_external_data(form_state, new_data, changed_paths) do
            {:ok, synced_state} -> {:cont, {:ok, Map.put(acc, form_id, synced_state)}}
            {:error, reason} -> {:halt, {:error, {form_id, reason}}}
          end
        end
      end)

    case forms_result do
      {:ok, forms_map} -> {:ok, %__MODULE__{group | data: new_data, forms: forms_map}}
      {:error, _} = error -> error
    end
  end

  defp action_changed_paths({:update_data, path, _raw, _meta}, state) when is_binary(path) do
    [path | dependent_paths(state, path)]
  end

  defp action_changed_paths({:add_item, path, _opts}, state) when is_binary(path) do
    [path | dependent_paths(state, path)]
  end

  defp action_changed_paths({:remove_item, path, _index}, state) when is_binary(path) do
    [path | dependent_paths(state, path)]
  end

  defp action_changed_paths({:move_item, path, _from, _to}, state) when is_binary(path) do
    [path | dependent_paths(state, path)]
  end

  defp action_changed_paths(_action, _state), do: nil

  defp dependent_paths(%State{} = state, path) do
    case Schema.resolve_at_data_path(
           state.schema,
           path,
           state.data,
           state.validator,
           state.validator_opts
         ) do
      {:ok, schema} ->
        case Map.get(schema, "x-dependents") || Map.get(schema, "x_dependents") do
          list when is_list(list) ->
            list
            |> Enum.map(&normalize_dependent_path/1)
            |> Enum.reject(&(&1 == ""))

          value when is_binary(value) ->
            [normalize_dependent_path(value)]

          _ ->
            []
        end

      {:error, _} ->
        []
    end
  end

  defp normalize_dependent_path(value) do
    value = to_string(value)

    if String.starts_with?(value, "#/") do
      Path.schema_pointer_to_data_path(value)
    else
      value
    end
  end

  defp form_id(form) do
    Map.get(form, :id) || Map.get(form, "id") || raise ArgumentError, "form id required"
  end

  defp merge_form_data(forms) do
    Enum.reduce(forms, %{}, fn form, acc ->
      data = Map.get(form, :data) || Map.get(form, "data")

      cond do
        is_map(data) and is_map(acc) -> deep_merge(acc, data)
        is_nil(data) -> acc
        acc == %{} -> data
        true -> acc
      end
    end)
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_val, right_val ->
      if is_map(left_val) and is_map(right_val) do
        deep_merge(left_val, right_val)
      else
        right_val
      end
    end)
  end

  defp deep_merge(_left, right), do: right

  defp normalize_opts(nil), do: %{}
  defp normalize_opts(opts) when is_map(opts), do: opts
  defp normalize_opts(opts) when is_list(opts), do: Map.new(opts)
end
