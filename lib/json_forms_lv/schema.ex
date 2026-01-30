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
end
