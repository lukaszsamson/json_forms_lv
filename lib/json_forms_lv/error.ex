defmodule JsonFormsLV.Error do
  @moduledoc """
  Normalized validation error.
  """

  @type t :: %__MODULE__{
          instance_path: String.t(),
          message: String.t(),
          keyword: String.t() | nil,
          schema_path: String.t() | nil,
          params: map(),
          source: :validator | :additional
        }

  defstruct instance_path: "",
            message: "",
            keyword: nil,
            schema_path: nil,
            params: %{},
            source: :validator
end
