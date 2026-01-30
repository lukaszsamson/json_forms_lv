defmodule JsonFormsLV.Validator do
  @moduledoc """
  Behaviour for JSON Schema validators.
  """

  @callback compile(schema :: map(), opts :: keyword()) :: {:ok, term()} | {:error, term()}
  @callback validate(compiled :: term(), data :: term(), opts :: keyword()) :: [
              JsonFormsLV.Error.t()
            ]

  @callback validate_fragment(
              compiled :: term(),
              fragment_pointer :: String.t(),
              value :: term(),
              opts :: keyword()
            ) :: [JsonFormsLV.Error.t()]
end
