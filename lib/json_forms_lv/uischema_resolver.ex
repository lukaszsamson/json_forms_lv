defmodule JsonFormsLV.UISchemaResolver do
  @moduledoc """
  Resolve local `$ref` pointers in UISchema documents.
  """

  @spec resolve(map(), map() | keyword()) :: {:ok, map()} | {:error, term()}
  def resolve(uischema, _opts \\ %{}) when is_map(uischema) do
    resolve_node(uischema, uischema, MapSet.new())
  end

  def resolve(_uischema, _opts), do: {:error, {:invalid_uischema, :expected_map}}

  defp resolve_node(%{"$ref" => ref} = node, root, seen) when is_binary(ref) do
    cond do
      not String.starts_with?(ref, "#") ->
        {:error, {:remote_ref, ref}}

      MapSet.member?(seen, ref) ->
        {:error, {:circular_ref, ref}}

      true ->
        with {:ok, fragment} <- resolve_pointer(root, ref),
             true <- is_map(fragment) do
          merged = Map.merge(fragment, Map.delete(node, "$ref"))
          resolve_node(merged, root, MapSet.put(seen, ref))
        else
          false -> {:error, {:invalid_uischema_ref, ref}}
          {:error, _} = error -> error
        end
    end
  end

  defp resolve_node(map, root, seen) when is_map(map) do
    map
    |> Enum.reduce_while({:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case resolve_node(value, root, seen) do
        {:ok, resolved} -> {:cont, {:ok, Map.put(acc, key, resolved)}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp resolve_node(list, root, seen) when is_list(list) do
    list
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, acc} ->
      case resolve_node(value, root, seen) do
        {:ok, resolved} -> {:cont, {:ok, [resolved | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, resolved} -> {:ok, Enum.reverse(resolved)}
      error -> error
    end
  end

  defp resolve_node(value, _root, _seen), do: {:ok, value}

  defp resolve_pointer(root, ref) do
    pointer = String.trim_leading(ref, "#")

    segments =
      pointer
      |> String.trim_leading("/")
      |> pointer_segments()

    do_resolve_pointer(root, segments, ref)
  end

  defp do_resolve_pointer(value, [], _ref), do: {:ok, value}

  defp do_resolve_pointer(%{} = map, [segment | rest], ref) do
    case Map.fetch(map, segment) do
      {:ok, value} -> do_resolve_pointer(value, rest, ref)
      :error -> {:error, {:invalid_uischema_ref, ref}}
    end
  end

  defp do_resolve_pointer(list, [segment | rest], ref) when is_list(list) do
    case Integer.parse(segment) do
      {index, ""} ->
        case Enum.at(list, index) do
          nil -> {:error, {:invalid_uischema_ref, ref}}
          value -> do_resolve_pointer(value, rest, ref)
        end

      _ ->
        {:error, {:invalid_uischema_ref, ref}}
    end
  end

  defp do_resolve_pointer(_value, _segments, ref), do: {:error, {:invalid_uischema_ref, ref}}

  defp pointer_segments(""), do: []

  defp pointer_segments(pointer) do
    pointer
    |> String.split("/", trim: true)
    |> Enum.map(&decode_pointer_segment/1)
  end

  defp decode_pointer_segment(segment) do
    segment
    |> String.replace("~1", "/")
    |> String.replace("~0", "~")
  end
end
