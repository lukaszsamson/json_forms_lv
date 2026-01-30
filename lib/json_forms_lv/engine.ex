defmodule JsonFormsLV.Engine do
  @moduledoc """
  Pure core engine functions.
  """

  alias JsonFormsLV.{Coercion, Data, Limits, Schema, State}

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

        {:ok,
         %State{
           schema: schema,
           uischema: uischema,
           data: data,
           opts: opts_with_limits
         }}
    end
  end

  @spec update_data(State.t(), String.t(), term(), map()) :: {:ok, State.t()} | {:error, term()}
  def update_data(%State{} = state, data_path, raw_value, meta \\ %{}) do
    schema =
      case Schema.resolve_at_data_path(state.schema, data_path) do
        {:ok, fragment} -> fragment
        {:error, _} -> nil
      end

    coerced_value = Coercion.coerce(raw_value, schema, state.opts)

    with {:ok, updated_data} <- Data.put(state.data, data_path, coerced_value) do
      touched = maybe_touch(state.touched, data_path, meta)
      raw_inputs = Map.delete(state.raw_inputs, data_path)

      {:ok, %State{state | data: updated_data, touched: touched, raw_inputs: raw_inputs}}
    end
  end

  @spec touch(State.t(), String.t()) :: {:ok, State.t()} | {:error, term()}
  def touch(%State{} = state, data_path) when is_binary(data_path) do
    touched = MapSet.put(state.touched, data_path)
    {:ok, %State{state | touched: touched}}
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
end
