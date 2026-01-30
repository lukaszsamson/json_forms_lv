defmodule JsonFormsLV.SchemaResolver do
  @moduledoc """
  Behaviour for resolving schema references.
  """

  @callback resolve(schema :: map(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
end
