defmodule JsonFormsLV.Data do
  @moduledoc """
  Helpers for reading and writing values at data paths.
  """

  alias JsonFormsLV.Path

  @spec get(term(), String.t()) :: {:ok, term()} | {:error, term()}
  def get(data, ""), do: {:ok, data}

  def get(data, path) when is_binary(path) do
    segments = Path.parse_data_path(path)
    do_get(data, segments, path)
  end

  @spec put(term(), String.t(), term()) :: {:ok, term()} | {:error, term()}
  def put(_data, path, _value) when not is_binary(path),
    do: {:error, {:invalid_path, path}}

  def put(_data, "", value), do: {:ok, value}

  def put(data, path, value) do
    segments = Path.parse_data_path(path)
    do_put(data, segments, value, path)
  end

  @spec update(term(), String.t(), (term() -> term())) :: {:ok, term()} | {:error, term()}
  def update(data, path, fun) when is_binary(path) and is_function(fun, 1) do
    with {:ok, current} <- get(data, path),
         {:ok, updated} <- put(data, path, fun.(current)) do
      {:ok, updated}
    end
  end

  defp do_get(current, [], _path), do: {:ok, current}

  defp do_get(current, [segment | rest], path) when is_map(current) and is_binary(segment) do
    case Map.fetch(current, segment) do
      {:ok, next} -> do_get(next, rest, path)
      :error -> {:error, {:invalid_path, path}}
    end
  end

  defp do_get(current, [segment | rest], path) when is_list(current) and is_integer(segment) do
    if segment >= 0 and segment < length(current) do
      do_get(Enum.at(current, segment), rest, path)
    else
      {:error, {:invalid_path, path}}
    end
  end

  defp do_get(_current, _segments, path), do: {:error, {:invalid_path, path}}

  defp do_put(_current, [], value, _path), do: {:ok, value}

  defp do_put(current, [segment], value, _path) when is_map(current) and is_binary(segment) do
    {:ok, Map.put(current, segment, value)}
  end

  defp do_put(current, [segment | rest], value, path)
       when is_map(current) and is_binary(segment) do
    child = Map.get(current, segment)

    cond do
      rest == [] ->
        {:ok, Map.put(current, segment, value)}

      is_map(child) or is_list(child) ->
        with {:ok, updated_child} <- do_put(child, rest, value, path) do
          {:ok, Map.put(current, segment, updated_child)}
        end

      is_nil(child) ->
        container = default_container(rest)

        with {:ok, updated_child} <- do_put(container, rest, value, path) do
          {:ok, Map.put(current, segment, updated_child)}
        end

      true ->
        {:error, {:invalid_path, path}}
    end
  end

  defp do_put(current, [segment], value, path) when is_list(current) and is_integer(segment) do
    if segment >= 0 and segment < length(current) do
      {:ok, List.replace_at(current, segment, value)}
    else
      {:error, {:invalid_path, path}}
    end
  end

  defp do_put(current, [segment | rest], value, path)
       when is_list(current) and is_integer(segment) do
    if segment >= 0 and segment < length(current) do
      child = Enum.at(current, segment)

      if is_map(child) or is_list(child) do
        with {:ok, updated_child} <- do_put(child, rest, value, path) do
          {:ok, List.replace_at(current, segment, updated_child)}
        end
      else
        {:error, {:invalid_path, path}}
      end
    else
      {:error, {:invalid_path, path}}
    end
  end

  defp do_put(_current, _segments, _value, path), do: {:error, {:invalid_path, path}}

  defp default_container([next | _]) when is_integer(next), do: []
  defp default_container(_), do: %{}
end
