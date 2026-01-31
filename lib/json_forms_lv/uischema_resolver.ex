defmodule JsonFormsLV.UISchemaResolver do
  @moduledoc """
  Resolve `$ref` pointers in UISchema documents.

  Supports local and remote refs with `$id` base resolution when a loader is provided.
  """

  @spec resolve(map(), map() | keyword()) :: {:ok, map()} | {:error, term()}
  def resolve(uischema, opts \\ %{})

  def resolve(uischema, opts) when is_map(uischema) do
    opts = normalize_opts(opts)
    loader = ref_loader(opts)
    root_base = resolve_id(Map.get(uischema, "$id"), nil)
    id_index = index_ids(uischema, root_base, %{})
    doc_cache = seed_cache(uischema, root_base)

    ctx = %{
      root: uischema,
      id_index: id_index,
      doc_cache: doc_cache,
      loader: loader,
      opts: opts,
      root_base: root_base
    }

    case resolve_node(uischema, ctx, root_base, MapSet.new()) do
      {:ok, resolved, _ctx} -> {:ok, resolved}
      {:error, _} = error -> error
    end
  end

  def resolve(_uischema, _opts), do: {:error, {:invalid_uischema, :expected_map}}

  defp resolve_node(%{"$ref" => ref} = node, ctx, base, seen) when is_binary(ref) do
    with {:ok, resolved, ctx, ref_key} <- resolve_ref(ref, ctx, base, seen),
         true <- is_map(resolved) do
      merged = Map.merge(resolved, Map.delete(node, "$ref"))
      base = update_base(merged, base)
      resolve_node(merged, ctx, base, MapSet.put(seen, ref_key))
    else
      false -> {:error, {:invalid_uischema_ref, ref}}
      {:error, _} = error -> error
    end
  end

  defp resolve_node(map, ctx, base, seen) when is_map(map) do
    base = update_base(map, base)

    map
    |> Enum.reduce_while({:ok, %{}, ctx}, fn {key, value}, {:ok, acc, ctx} ->
      case resolve_node(value, ctx, base, seen) do
        {:ok, resolved, ctx} -> {:cont, {:ok, Map.put(acc, key, resolved), ctx}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp resolve_node(list, ctx, base, seen) when is_list(list) do
    list
    |> Enum.reduce_while({:ok, [], ctx}, fn value, {:ok, acc, ctx} ->
      case resolve_node(value, ctx, base, seen) do
        {:ok, resolved, ctx} -> {:cont, {:ok, [resolved | acc], ctx}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, resolved, ctx} -> {:ok, Enum.reverse(resolved), ctx}
      error -> error
    end
  end

  defp resolve_node(value, ctx, _base, _seen), do: {:ok, value, ctx}

  defp resolve_ref(ref, ctx, base, seen) do
    with {:ok, {doc_uri, fragment, ref_key}} <- resolve_ref_target(ref, base),
         false <- MapSet.member?(seen, ref_key) do
      case Map.fetch(ctx.id_index, ref_key) do
        {:ok, node} ->
          {:ok, node, ctx, ref_key}

        :error ->
          with {:ok, doc, ctx} <- fetch_doc(doc_uri, ctx),
               {:ok, resolved} <- resolve_fragment(doc, fragment, ref_key) do
            {:ok, resolved, ctx, ref_key}
          end
      end
    else
      true -> {:error, {:circular_ref, ref_key(base, ref)}}
      {:error, _} = error -> error
    end
  end

  defp resolve_ref_target(ref, base) do
    cond do
      String.starts_with?(ref, "#") ->
        fragment = String.trim_leading(ref, "#")
        doc_uri = base && drop_fragment(base)
        ref_key = canonical_ref_key(doc_uri, fragment)
        {:ok, {doc_uri, fragment, ref_key}}

      true ->
        with {:ok, resolved} <- resolve_remote_ref(ref, base) do
          uri = URI.parse(resolved)
          doc_uri = drop_fragment(resolved)
          fragment = uri.fragment || ""
          ref_key = canonical_ref_key(doc_uri, fragment)
          {:ok, {doc_uri, fragment, ref_key}}
        end
    end
  end

  defp resolve_remote_ref(ref, base) do
    uri = URI.parse(ref)

    cond do
      uri.scheme != nil ->
        {:ok, ref}

      is_binary(base) ->
        base = drop_fragment(base)
        merged = URI.merge(base, ref)
        {:ok, URI.to_string(merged)}

      true ->
        {:error, {:missing_base_uri, ref}}
    end
  rescue
    _ -> {:error, {:invalid_uischema_ref, ref}}
  end

  defp fetch_doc(nil, ctx), do: {:ok, ctx.root, ctx}

  defp fetch_doc(doc_uri, ctx) when is_binary(doc_uri) do
    doc_uri = drop_fragment(doc_uri)

    case Map.fetch(ctx.doc_cache, doc_uri) do
      {:ok, doc} ->
        {:ok, doc, ctx}

      :error ->
        load_remote_doc(doc_uri, ctx)
    end
  end

  defp load_remote_doc(doc_uri, %{loader: nil}), do: {:error, {:remote_ref, doc_uri}}

  defp load_remote_doc(doc_uri, ctx) do
    case ctx.loader.(doc_uri, ctx.opts) do
      {:ok, doc} when is_map(doc) ->
        id_index = index_ids(doc, doc_uri, ctx.id_index)
        doc_cache = Map.put(ctx.doc_cache, doc_uri, doc)
        {:ok, doc, %{ctx | id_index: id_index, doc_cache: doc_cache}}

      {:ok, _} ->
        {:error, {:invalid_uischema_ref, doc_uri}}

      {:error, _} = error ->
        error
    end
  end

  defp resolve_fragment(doc, "", _ref), do: {:ok, doc}
  defp resolve_fragment(doc, nil, _ref), do: {:ok, doc}

  defp resolve_fragment(doc, fragment, ref) when is_binary(fragment) do
    if String.starts_with?(fragment, "/") do
      resolve_pointer_fragment(doc, fragment, ref)
    else
      {:error, {:invalid_uischema_ref, ref}}
    end
  end

  defp resolve_pointer_fragment(doc, fragment, ref) do
    segments =
      fragment
      |> String.trim_leading("/")
      |> pointer_segments()

    do_resolve_pointer(doc, segments, ref)
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

  defp normalize_opts(nil), do: %{}
  defp normalize_opts(opts) when is_map(opts), do: opts
  defp normalize_opts(opts) when is_list(opts), do: Map.new(opts)

  defp ref_loader(opts) do
    case Map.get(opts, :uischema_ref_loader) || Map.get(opts, "uischema_ref_loader") do
      fun when is_function(fun, 2) ->
        fun

      fun when is_function(fun, 1) ->
        fn uri, _opts -> fun.(uri) end

      {mod, fun} when is_atom(mod) and is_atom(fun) ->
        fn uri, opts -> apply(mod, fun, [uri, opts]) end

      _ ->
        nil
    end
  end

  defp resolve_id(nil, _base), do: nil

  defp resolve_id(id, base) when is_binary(id) do
    if base do
      base = drop_fragment(base)
      URI.merge(base, id) |> URI.to_string()
    else
      id
    end
  rescue
    _ -> id
  end

  defp resolve_id(_id, _base), do: nil

  defp update_base(%{"$id" => id}, base) when is_binary(id) do
    resolve_id(id, base) || base
  end

  defp update_base(_node, base), do: base

  defp index_ids(map, base, acc) when is_map(map) do
    {resolved_id, next_base} = resolve_base(map, base)

    acc =
      if is_binary(resolved_id) do
        Map.put(acc, resolved_id, map)
      else
        acc
      end

    Enum.reduce(map, acc, fn {_key, value}, acc ->
      index_ids(value, next_base, acc)
    end)
  end

  defp index_ids(list, base, acc) when is_list(list) do
    Enum.reduce(list, acc, fn value, acc -> index_ids(value, base, acc) end)
  end

  defp index_ids(_value, _base, acc), do: acc

  defp seed_cache(_uischema, nil), do: %{}

  defp seed_cache(uischema, base) do
    %{drop_fragment(base) => uischema}
  end

  defp drop_fragment(uri) when is_binary(uri) do
    parsed = URI.parse(uri)

    %{parsed | fragment: nil}
    |> URI.to_string()
  end

  defp canonical_ref_key(nil, fragment) do
    fragment = fragment || ""

    if fragment == "" do
      "#"
    else
      "#" <> fragment
    end
  end

  defp canonical_ref_key(doc_uri, ""), do: doc_uri
  defp canonical_ref_key(doc_uri, nil), do: doc_uri
  defp canonical_ref_key(doc_uri, fragment), do: doc_uri <> "#" <> fragment

  defp ref_key(base, ref) do
    case resolve_ref_target(ref, base) do
      {:ok, {_doc_uri, _fragment, key}} -> key
      _ -> ref
    end
  end

  defp resolve_base(map, base) when is_map(map) do
    case Map.get(map, "$id") do
      id when is_binary(id) ->
        resolved = resolve_id(id, base)
        {resolved, resolved || base}

      _ ->
        {nil, base}
    end
  end
end
