defmodule JsonFormsLV.Event do
  @moduledoc """
  Helpers for decoding event payloads into normalized actions.
  """

  @spec extract_change(map(), keyword()) ::
          {:ok, %{path: String.t(), value: term(), meta: map()}} | {:error, term()}
  def extract_change(params, opts \\ []) when is_map(params) do
    params = normalize_event_params(params)

    with {:ok, path} <- extract_path(params, opts) do
      value = extract_value(params, path, opts)
      meta = Map.get(params, "meta", %{})
      {:ok, %{path: path, value: value, meta: meta}}
    end
  end

  @spec extract_blur(map(), keyword()) ::
          {:ok, %{path: String.t(), meta: map()}} | {:error, term()}
  def extract_blur(params, opts \\ []) when is_map(params) do
    params = normalize_event_params(params)

    with {:ok, path} <- extract_path(params, opts) do
      meta = Map.get(params, "meta", %{})
      {:ok, %{path: path, meta: meta}}
    end
  end

  defp extract_path(params, opts) do
    cond do
      is_binary(params["path"]) ->
        {:ok, params["path"]}

      is_list(params["_target"]) ->
        form_key = Keyword.get(opts, :form_key, "jf")
        {:ok, target_to_path(params["_target"], form_key)}

      true ->
        {:error, :missing_path}
    end
  end

  defp extract_value(params, path, opts) do
    value =
      case Map.fetch(params, "value") do
        {:ok, value} ->
          value

        :error ->
          form_key = Keyword.get(opts, :form_key, "jf")

          case params do
            %{^form_key => form_params} when is_map(form_params) ->
              Map.get(form_params, path)

            _ ->
              Map.get(params, path)
          end
      end

    normalize_value(value)
  end

  defp normalize_value(["false", "true"]), do: "true"
  defp normalize_value(["false"]), do: "false"
  defp normalize_value(["true"]), do: "true"
  defp normalize_value(value) when is_list(value), do: value
  defp normalize_value(value), do: value

  defp normalize_event_params(%{"value" => value} = params) when is_map(value) do
    value_params = normalize_value_params(value)
    Map.merge(value_params, Map.delete(params, "value"))
  end

  defp normalize_event_params(params), do: params

  defp normalize_value_params(value) do
    Enum.reduce(value, %{}, fn {key, val}, acc ->
      Map.put(acc, to_string(key), val)
    end)
  end

  defp target_to_path([form_key | rest], form_key) do
    Enum.join(rest, ".")
  end

  defp target_to_path(rest, _form_key) do
    Enum.join(rest, ".")
  end
end
