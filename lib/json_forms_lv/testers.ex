defmodule JsonFormsLV.Testers do
  @moduledoc """
  Helper testers for custom renderers.

  These helpers return tester functions compatible with `JsonFormsLV.Renderer`.

  ## Examples

      alias JsonFormsLV.Testers

      def tester(uischema, schema, ctx) do
        Testers.rank_with(25, Testers.all_of([
          Testers.ui_type_is("Control"),
          Testers.schema_type_is("string"),
          Testers.has_option("format", "custom")
        ])).(uischema, schema, ctx)
      end
  """

  @doc """
  Match a UISchema `type` value.
  """
  @spec ui_type_is(String.t()) :: (map(), map() | nil, map() -> boolean())
  def ui_type_is(type) when is_binary(type) do
    fn uischema, _schema, _ctx ->
      Map.get(uischema || %{}, "type") == type
    end
  end

  @doc """
  Match a schema `type` (string or union list).
  """
  @spec schema_type_is(String.t()) :: (map(), map() | nil, map() -> boolean())
  def schema_type_is(type) when is_binary(type) do
    fn _uischema, schema, _ctx ->
      case Map.get(schema || %{}, "type") do
        ^type -> true
        types when is_list(types) -> type in types
        _ -> false
      end
    end
  end

  @doc """
  Match a schema `format` value.
  """
  @spec format_is(String.t()) :: (map(), map() | nil, map() -> boolean())
  def format_is(format) when is_binary(format) do
    fn _uischema, schema, _ctx ->
      Map.get(schema || %{}, "format") == format
    end
  end

  @doc """
  Match a UISchema option flag set to true.
  """
  @spec has_option(String.t()) :: (map(), map() | nil, map() -> boolean())
  def has_option(key) when is_binary(key) do
    fn uischema, _schema, _ctx ->
      options = Map.get(uischema || %{}, "options", %{})
      Map.get(options, key) == true
    end
  end

  @doc """
  Match a UISchema option with an exact value.
  """
  @spec has_option(String.t(), term()) :: (map(), map() | nil, map() -> boolean())
  def has_option(key, value) when is_binary(key) do
    fn uischema, _schema, _ctx ->
      options = Map.get(uischema || %{}, "options", %{})
      Map.get(options, key) == value
    end
  end

  @doc """
  Match a UISchema scope suffix.
  """
  @spec scope_ends_with(String.t()) :: (map(), map() | nil, map() -> boolean())
  def scope_ends_with(suffix) when is_binary(suffix) do
    fn uischema, _schema, _ctx ->
      case Map.get(uischema || %{}, "scope") do
        scope when is_binary(scope) -> String.ends_with?(scope, suffix)
        _ -> false
      end
    end
  end

  @doc """
  Return a tester that yields the provided rank when the predicate passes.
  """
  @spec rank_with(non_neg_integer(), (map(), map() | nil, map() -> term())) ::
          (map(), map() | nil, map() -> non_neg_integer() | :not_applicable)
  def rank_with(rank, tester_fun) when is_integer(rank) and rank >= 0 do
    fn uischema, schema, ctx ->
      case tester_fun.(uischema, schema, ctx) do
        true -> rank
        false -> :not_applicable
        :not_applicable -> :not_applicable
        value when is_integer(value) and value > 0 -> rank
        _ -> :not_applicable
      end
    end
  end

  @doc """
  Combine testers with logical AND.
  """
  @spec all_of([function()]) :: (map(), map() | nil, map() -> boolean())
  def all_of(testers) when is_list(testers) do
    fn uischema, schema, ctx ->
      Enum.all?(testers, fn tester -> tester.(uischema, schema, ctx) == true end)
    end
  end

  @doc """
  Combine testers with logical OR.
  """
  @spec any_of([function()]) :: (map(), map() | nil, map() -> boolean())
  def any_of(testers) when is_list(testers) do
    fn uischema, schema, ctx ->
      Enum.any?(testers, fn tester -> tester.(uischema, schema, ctx) == true end)
    end
  end

  @doc """
  Negate a tester predicate.
  """
  @spec not_of(function()) :: (map(), map() | nil, map() -> boolean())
  def not_of(tester) when is_function(tester) do
    fn uischema, schema, ctx ->
      tester.(uischema, schema, ctx) != true
    end
  end

  @doc """
  Increase a tester rank by the given amount.
  """
  @spec with_increased_rank(function(), non_neg_integer()) ::
          (map(), map() | nil, map() -> non_neg_integer() | :not_applicable)
  def with_increased_rank(tester, increment) when is_function(tester) and is_integer(increment) do
    fn uischema, schema, ctx ->
      case tester.(uischema, schema, ctx) do
        :not_applicable -> :not_applicable
        rank when is_integer(rank) -> rank + increment
        true -> increment
        false -> :not_applicable
        _ -> :not_applicable
      end
    end
  end

  @doc """
  Match a schema predicate.
  """
  @spec schema_matches(function()) :: (map(), map() | nil, map() -> boolean())
  def schema_matches(predicate) when is_function(predicate) do
    arity = function_arity(predicate)

    fn uischema, schema, ctx ->
      case arity do
        1 -> predicate.(schema)
        2 -> predicate.(schema, ctx)
        _ -> predicate.(uischema, schema, ctx)
      end
    end
  end

  @doc """
  Match a schema fragment at the given pointer.
  """
  @spec schema_sub_path_matches(String.t(), function()) :: (map(), map() | nil, map() ->
                                                              boolean())
  def schema_sub_path_matches(pointer, predicate)
      when is_binary(pointer) and is_function(predicate) do
    arity = function_arity(predicate)

    fn uischema, schema, ctx ->
      case JsonFormsLV.Schema.resolve_pointer(schema || %{}, pointer) do
        {:ok, fragment} ->
          case arity do
            1 -> predicate.(fragment)
            2 -> predicate.(fragment, ctx)
            _ -> predicate.(uischema, fragment, ctx)
          end

        {:error, _} ->
          false
      end
    end
  end

  @doc """
  Match date controls (`format: "date"`).
  """
  @spec is_date_control() :: (map(), map() | nil, map() -> boolean())
  def is_date_control do
    all_of([ui_type_is("Control"), format_is("date")])
  end

  @doc """
  Match time controls (`format: "time"`).
  """
  @spec is_time_control() :: (map(), map() | nil, map() -> boolean())
  def is_time_control do
    all_of([ui_type_is("Control"), format_is("time")])
  end

  @doc """
  Match range controls (number/integer with slider option).
  """
  @spec is_range_control() :: (map(), map() | nil, map() -> boolean())
  def is_range_control do
    fn uischema, schema, _ctx ->
      options = Map.get(uischema || %{}, "options", %{})
      slider? = Map.get(options, "slider") == true

      type =
        case Map.get(schema || %{}, "type") do
          type when is_binary(type) -> type
          types when is_list(types) -> types
          _ -> nil
        end

      slider? and
        (type == "number" or type == "integer" or
           (is_list(type) and
              ("number" in type or "integer" in type)))
    end
  end

  defp function_arity(fun) do
    case Function.info(fun, :arity) do
      {:arity, arity} -> arity
      _ -> 1
    end
  end
end
