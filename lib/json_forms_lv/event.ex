defmodule JsonFormsLV.Event do
  @moduledoc """
  Helpers for decoding event payloads into normalized actions.
  """

  @spec extract_change(map(), keyword()) ::
          {:ok, %{path: String.t(), value: term(), meta: map()}} | {:error, term()}
  def extract_change(params, opts \\ []) when is_map(params) do
    with {:ok, path} <- extract_path(params, opts) do
      value = extract_value(params, path)
      meta = Map.get(params, "meta", %{})
      {:ok, %{path: path, value: value, meta: meta}}
    end
  end

  @spec extract_blur(map(), keyword()) ::
          {:ok, %{path: String.t(), meta: map()}} | {:error, term()}
  def extract_blur(params, opts \\ []) when is_map(params) do
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

  defp extract_value(params, path) do
    case Map.fetch(params, "value") do
      {:ok, value} -> value
      :error -> Map.get(params, path)
    end
  end

  defp target_to_path([form_key | rest], form_key) do
    Enum.join(rest, ".")
  end

  defp target_to_path(rest, _form_key) do
    Enum.join(rest, ".")
  end
end
