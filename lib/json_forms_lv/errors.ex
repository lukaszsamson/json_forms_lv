defmodule JsonFormsLV.Errors do
  @moduledoc """
  Helpers for normalizing, merging, and mapping errors.
  """

  alias JsonFormsLV.{Error, Limits, Path, State}

  @spec normalize_additional([map() | Error.t()]) :: [Error.t()]
  def normalize_additional(errors) when is_list(errors) do
    Enum.map(errors, &normalize_additional_error/1)
  end

  @spec from_jsv(JSV.ValidationError.t()) :: [Error.t()]
  def from_jsv(error) do
    normalized = JSV.normalize_error(error, keys: :strings)
    details = Map.get(normalized, "details", [])

    details
    |> Enum.reduce([], &flatten_jsv_error/2)
    |> Enum.reverse()
  end

  @spec merge([Error.t()], [Error.t()], map()) :: [Error.t()]
  def merge(validator_errors, additional_errors, opts) do
    errors = validator_errors ++ additional_errors
    deduped = dedupe(errors)
    cap_errors(deduped, opts)
  end

  @spec errors_for_control(State.t(), String.t()) :: [Error.t()]
  def errors_for_control(%State{} = state, path) do
    opts = state.opts || %{}
    mapping = Map.get(opts, :error_mapping, :exact)
    show_validator? = show_validator_errors?(state, path)
    show_additional? = show_additional_errors?(state, path)

    Enum.filter(state.errors || [], fn error ->
      data_path = error_data_path(error)
      matches = match_path?(data_path, path, mapping)

      cond do
        error.source == :validator -> matches and show_validator?
        error.source == :additional -> matches and show_additional?
        true -> false
      end
    end)
  end

  @spec show_validator_errors?(State.t(), String.t()) :: boolean()
  def show_validator_errors?(%State{} = state, path) do
    case state.validation_mode do
      :validate_and_show -> state.submitted || MapSet.member?(state.touched, path)
      :validate_and_hide -> false
      :no_validation -> false
    end
  end

  @spec has_additional_errors?([Error.t()]) :: boolean()
  def has_additional_errors?(errors) do
    Enum.any?(errors, &(&1.source == :additional))
  end

  defp normalize_additional_error(%Error{} = error) do
    %Error{error | source: :additional}
  end

  defp normalize_additional_error(error) when is_map(error) do
    %Error{
      instance_path:
        fetch_error_value(
          error,
          ["instancePath", "instance_path", :instancePath, :instance_path],
          ""
        ),
      message: fetch_error_value(error, ["message", :message], ""),
      keyword: fetch_error_value(error, ["keyword", :keyword], nil),
      schema_path:
        fetch_error_value(error, ["schemaPath", "schema_path", :schemaPath, :schema_path], nil),
      params: fetch_error_value(error, ["params", :params], %{}),
      source: :additional
    }
  end

  defp normalize_additional_error(_), do: %Error{source: :additional}

  defp fetch_error_value(map, keys, default) do
    Enum.find_value(keys, default, fn key ->
      case Map.fetch(map, key) do
        {:ok, value} -> value
        :error -> nil
      end
    end)
  end

  defp flatten_jsv_error(unit, acc) when is_map(unit) do
    errors = Map.get(unit, "errors", [])
    instance_path = normalize_jsv_path(Map.get(unit, "instanceLocation", ""))
    schema_path = normalize_jsv_path(Map.get(unit, "schemaLocation"))

    acc =
      Enum.reduce(errors, acc, fn error, acc ->
        keyword = Map.get(error, "kind")
        message = Map.get(error, "message") || ""
        params = Map.get(error, "params") || %{}

        error_struct = %Error{
          instance_path: instance_path,
          message: message,
          keyword: keyword && to_string(keyword),
          schema_path: schema_path,
          params: params,
          source: :validator
        }

        [error_struct | acc]
      end)

    details =
      Enum.flat_map(errors, fn error ->
        Map.get(error, "details", [])
      end)

    nested_units = Map.get(unit, "details", [])

    acc = Enum.reduce(details, acc, &flatten_jsv_error/2)
    Enum.reduce(nested_units, acc, &flatten_jsv_error/2)
  end

  defp flatten_jsv_error(_unit, acc), do: acc

  defp normalize_jsv_path(nil), do: nil
  defp normalize_jsv_path("#"), do: ""

  defp normalize_jsv_path(path) when is_binary(path) do
    path = String.trim_leading(path, "#")

    cond do
      path == "" -> ""
      String.starts_with?(path, "/") -> path
      true -> "/" <> path
    end
  end

  defp dedupe(errors) do
    {result, _seen} =
      Enum.reduce(errors, {[], MapSet.new()}, fn error, {acc, seen} ->
        key = {error.instance_path, error.message, error.keyword, error.schema_path}

        if MapSet.member?(seen, key) do
          {acc, seen}
        else
          {[error | acc], MapSet.put(seen, key)}
        end
      end)

    Enum.reverse(result)
  end

  defp cap_errors(errors, opts) do
    max_errors = Map.get(opts || %{}, :max_errors, Limits.defaults().max_errors)
    Enum.take(errors, max_errors)
  end

  defp error_data_path(%Error{} = error) do
    base_path = Path.instance_path_to_data_path(error.instance_path || "")
    missing = fetch_error_value(error.params || %{}, ["missingProperty", :missingProperty], nil)

    if error.keyword == "required" and is_binary(missing) do
      Path.join(base_path, missing)
    else
      base_path
    end
  end

  defp match_path?(data_path, path, :subtree) do
    cond do
      path == "" -> true
      data_path == path -> true
      String.starts_with?(data_path, path <> ".") -> true
      true -> false
    end
  end

  defp match_path?(data_path, path, _mode), do: data_path == path

  defp show_additional_errors?(%State{} = state, path) do
    opts = state.opts || %{}

    if Map.get(opts, :hide_additional_errors?, false) do
      false
    else
      case Map.get(opts, :additional_errors_gate, :always) do
        :touched_or_submitted ->
          state.submitted || MapSet.member?(state.touched, path)

        _ ->
          true
      end
    end
  end
end
