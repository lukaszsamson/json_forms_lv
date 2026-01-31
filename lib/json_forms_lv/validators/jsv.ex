defmodule JsonFormsLV.Validators.JSV do
  @moduledoc """
  JSV-based validator adapter.

  Internal `$ref` resolution is delegated to JSV during compilation. Validation
  opts default to `cast: false` to avoid implicit type coercion.
  """

  alias JsonFormsLV.{Errors, Schema}

  @behaviour JsonFormsLV.Validator

  defstruct root: nil, schema: %{}, opts: []

  @type t :: %__MODULE__{
          root: JSV.Root.t(),
          schema: map(),
          opts: keyword()
        }

  @impl JsonFormsLV.Validator
  def compile(schema, opts) when is_map(schema) and is_list(opts) do
    jsv_opts = build_opts(opts)

    case JSV.build(schema, jsv_opts) do
      {:ok, root} -> {:ok, %__MODULE__{root: root, schema: schema, opts: opts}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl JsonFormsLV.Validator
  def validate(%__MODULE__{root: root}, data, opts) when is_list(opts) do
    case JSV.validate(data, root, validate_opts(opts)) do
      {:ok, _data} -> []
      {:error, error} -> Errors.from_jsv(error)
    end
  end

  @impl JsonFormsLV.Validator
  def validate_fragment(%__MODULE__{schema: schema}, fragment_pointer, value, opts)
      when is_binary(fragment_pointer) and is_list(opts) do
    case Schema.resolve_pointer(schema, fragment_pointer) do
      {:ok, fragment} ->
        case JSV.build(fragment, build_opts(opts)) do
          {:ok, root} ->
            case JSV.validate(value, root, validate_opts(opts)) do
              {:ok, _data} -> []
              {:error, error} -> Errors.from_jsv(error)
            end

          {:error, _reason} ->
            []
        end

      {:error, _reason} ->
        []
    end
  end

  defp build_opts(opts) do
    base = Keyword.get(opts, :jsv_opts, [])

    base
    |> put_opt(:default_meta, opts)
    |> put_opt(:formats, opts)
    |> put_opt(:resolver, opts)
  end

  defp validate_opts(opts) do
    Keyword.get(opts, :jsv_validate_opts, cast: false)
  end

  defp put_opt(acc, key, opts) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> Keyword.put(acc, key, value)
      :error -> acc
    end
  end
end
