defmodule JsonFormsLV.DynamicEnums do
defmodule JsonFormsLV.DynamicEnums do
  @moduledoc """
  Resolve dynamic enums defined via `x-url` or `x-endpoint` in JSON Schema.

  The resolver replaces the enum/oneOf values before validation and rendering.
  """

  @spec resolve(map(), map() | keyword()) :: {:ok, map()} | {:error, term()}
  def resolve(schema, opts \\ %{}) when is_map(schema) do
    opts = normalize_opts(opts)
    loader = enum_loader(opts)
    base_url = enum_base_url(schema, opts)

    case resolve_node(schema, loader, base_url, %{}) do
      {:ok, resolved, _cache} -> {:ok, resolved}
      {:error, _} = error -> error
    end
  end

  def resolve(_schema, _opts), do: {:error, {:invalid_schema, :expected_map}}

  defp resolve_node(schema, loader, base_url, cache) when is_map(schema) do
    case maybe_resolve_enum(schema, loader, base_url, cache) do
      {:ok, schema, cache} ->
        schema
        |> Enum.reduce_while({:ok, %{}, cache}, fn {key, value}, {:ok, acc, cache} ->
          case resolve_node(value, loader, base_url, cache) do
            {:ok, resolved, cache} -> {:cont, {:ok, Map.put(acc, key, resolved), cache}}
            {:error, _} = error -> {:halt, error}
          end
        end)

      {:error, _} = error ->
        error
    end
  end

  defp resolve_node(list, loader, base_url, cache) when is_list(list) do
    list
    |> Enum.reduce_while({:ok, [], cache}, fn value, {:ok, acc, cache} ->
      case resolve_node(value, loader, base_url, cache) do
        {:ok, resolved, cache} -> {:cont, {:ok, [resolved | acc], cache}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, resolved, cache} -> {:ok, Enum.reverse(resolved), cache}
      error -> error
    end
  end

  defp resolve_node(value, _loader, _base_url, cache), do: {:ok, value, cache}

  defp maybe_resolve_enum(schema, loader, base_url, cache) do
    url = Map.get(schema, "x-url") || Map.get(schema, "x-endpoint")

    if is_binary(url) do
      with {:ok, full_url} <- resolve_url(url, base_url),
           {:ok, values, cache} <- fetch_enum(full_url, loader, cache),
           {:ok, schema} <- apply_enum(schema, values) do
        {:ok, schema, cache}
      else
        {:error, _} = error -> error
      end
    else
      {:ok, schema, cache}
    end
  end

  defp fetch_enum(url, loader, cache) do
    case cache do
      %{^url => values} ->
        {:ok, values, cache}

      _ ->
        case loader.(url) do
          {:ok, values} -> {:ok, values, Map.put(cache, url, values)}
          {:error, _} = error -> error
        end
    end
  end

  defp apply_enum(schema, %{"enum" => enum}) when is_list(enum) do
    {:ok, Map.put(schema, "enum", enum)}
  end

  defp apply_enum(schema, %{"oneOf" => one_of}) when is_list(one_of) do
    {:ok, Map.put(schema, "oneOf", one_of)}
  end

  defp apply_enum(schema, values) when is_list(values) do
    if Enum.all?(values, &is_map/1) and Enum.any?(values, &Map.has_key?(&1, "const")) do
      {:ok, Map.put(schema, "oneOf", values)}
    else
      {:ok, Map.put(schema, "enum", values)}
    end
  end

  defp apply_enum(_schema, _values), do: {:error, {:invalid_enum_response, :unsupported}}

  defp resolve_url(url, base_url) do
    uri = URI.parse(url)

    cond do
      uri.scheme != nil ->
        {:ok, url}

      is_binary(base_url) ->
        {:ok, URI.merge(base_url, url) |> URI.to_string()}

      true ->
        {:error, {:missing_base_url, url}}
    end
  rescue
    _ -> {:error, {:invalid_enum_url, url}}
  end

  defp enum_loader(opts) do
    case Map.get(opts, :enum_loader) || Map.get(opts, "enum_loader") do
      fun when is_function(fun, 2) ->
        fn url -> fun.(url, opts) end

      fun when is_function(fun, 1) ->
        fun

      {mod, fun} when is_atom(mod) and is_atom(fun) ->
        fn url -> apply(mod, fun, [url, opts]) end

      _ ->
        fn url -> default_loader(url, opts) end
    end
  end

  defp default_loader(url, opts) do
    request_opts =
      Map.get(opts, :enum_loader_opts) || Map.get(opts, "enum_loader_opts") || []

    request_opts =
      cond do
        is_list(request_opts) -> request_opts
        is_map(request_opts) -> Map.to_list(request_opts)
        true -> []
      end

    case Req.get(url, Keyword.merge([decode_json: true], request_opts)) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp enum_base_url(schema, opts) do
    base = Map.get(opts, :enum_base_url) || Map.get(opts, "enum_base_url")

    cond do
      is_binary(base) -> drop_fragment(base)
      is_binary(schema["$id"]) -> drop_fragment(schema["$id"])
      true -> nil
    end
  end

  defp drop_fragment(uri) when is_binary(uri) do
    parsed = URI.parse(uri)
    %{parsed | fragment: nil} |> URI.to_string()
  end

  defp normalize_opts(nil), do: %{}
  defp normalize_opts(opts) when is_map(opts), do: opts
  defp normalize_opts(opts) when is_list(opts), do: Map.new(opts)
end
