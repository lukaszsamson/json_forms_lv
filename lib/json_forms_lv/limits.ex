defmodule JsonFormsLV.Limits do
  @moduledoc """
  Central safety limits for the engine.
  """

  @defaults %{
    max_elements: 1_000,
    max_depth: 30,
    max_errors: 100,
    max_data_bytes: 1_000_000
  }

  @spec defaults() :: map()
  def defaults do
    @defaults
  end

  @spec with_defaults(map()) :: map()
  def with_defaults(opts) when is_map(opts) do
    Map.merge(@defaults, opts)
  end
end
