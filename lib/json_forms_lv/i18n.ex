defmodule JsonFormsLV.I18n do
  @moduledoc """
  Translation helpers for labels and errors.
  """

  alias JsonFormsLV.Error

  @spec translate_error(Error.t(), map(), map()) :: String.t()
  def translate_error(%Error{} = error, i18n, ctx) when is_map(i18n) and is_map(ctx) do
    translate = Map.get(i18n, :translate) || Map.get(i18n, "translate")
    translate_error = Map.get(i18n, :translate_error) || Map.get(i18n, "translateError")

    case translate_error do
      fun when is_function(fun, 2) ->
        fun.(error, ctx) || error.message

      fun when is_function(fun, 3) ->
        fun.(error, translate, ctx[:uischema]) || error.message

      _ ->
        translate_error_fallback(error, translate, ctx)
    end
  end

  def translate_error(%Error{} = error, _i18n, _ctx), do: error.message

  defp translate_error_fallback(%Error{} = error, translate, ctx) do
    if is_function(translate, 3) do
      base = base_key(ctx)
      keyword = error.keyword

      keys =
        [
          base && base <> ".error.custom",
          keyword && base && base <> ".error." <> keyword,
          keyword && "error." <> keyword
        ]
        |> Enum.filter(& &1)

      Enum.find_value(keys, error.message, fn key ->
        translate.(key, error.message, ctx)
      end)
    else
      error.message
    end
  end

  defp base_key(ctx) do
    uischema = ctx[:uischema] || %{}
    schema = ctx[:schema] || %{}

    cond do
      is_binary(uischema["i18n"]) -> uischema["i18n"]
      is_binary(schema["i18n"]) -> schema["i18n"]
      true -> derive_from_path(ctx[:path])
    end
  end

  defp derive_from_path(path) when is_binary(path) do
    path
    |> String.split(".", trim: true)
    |> Enum.reject(&numeric_segment?/1)
    |> Enum.join(".")
  end

  defp derive_from_path(_), do: nil

  defp numeric_segment?(segment) do
    case Integer.parse(segment) do
      {_, ""} -> true
      _ -> false
    end
  end
end
