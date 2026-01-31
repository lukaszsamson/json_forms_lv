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

  def translate_label(default, i18n, ctx) do
    translate_with_suffix(default, i18n, ctx, ".label")
  end

  def translate_description(default, i18n, ctx) do
    translate_with_suffix(default, i18n, ctx, ".description")
  end

  def translate_label_text(default, i18n, ctx) do
    translate = translate_fun(i18n)
    uischema = ctx[:uischema] || %{}

    cond do
      not is_binary(default) ->
        default

      is_binary(uischema["i18n"]) ->
        translate_key(translate, uischema["i18n"] <> ".text", default, ctx)

      true ->
        translate_key(translate, default, default, ctx)
    end
  end

  def translate_enum(value, default, i18n, ctx) do
    translate = translate_fun(i18n)

    key =
      case base_key(ctx) do
        nil -> nil
        base -> base <> "." <> to_string(value)
      end

    translate_key(translate, key, default, ctx)
  end

  def translate_one_of(option, value, default, i18n, ctx) do
    translate = translate_fun(i18n)

    key =
      cond do
        is_binary(option["i18n"]) ->
          option["i18n"] <> ".label"

        is_binary(option["i18nKey"]) ->
          option["i18nKey"] <> ".label"

        is_binary(option["i18nKeyPrefix"]) ->
          option["i18nKeyPrefix"] <> ".label"

        is_binary(option["i18nKeySuffix"]) and is_binary(base_key(ctx)) ->
          base_key(ctx) <> "." <> option["i18nKeySuffix"] <> ".label"

        is_binary(base_key(ctx)) and not is_nil(value) ->
          base_key(ctx) <> "." <> to_string(value)

        true ->
          nil
      end

    translate_key(translate, key, default, ctx)
  end

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

  defp translate_with_suffix(nil, _i18n, _ctx, _suffix), do: nil

  defp translate_with_suffix(default, i18n, ctx, suffix) when is_binary(default) do
    translate = translate_fun(i18n)

    key =
      case base_key(ctx) do
        nil -> nil
        base -> base <> suffix
      end

    translate_key(translate, key, default, ctx)
  end

  defp translate_with_suffix(default, _i18n, _ctx, _suffix), do: default

  defp translate_key(translate, key, default, ctx) do
    cond do
      is_function(translate, 3) and is_binary(key) ->
        translate.(key, default, ctx) || default

      true ->
        default
    end
  end

  defp translate_fun(i18n) do
    Map.get(i18n || %{}, :translate) || Map.get(i18n || %{}, "translate")
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
