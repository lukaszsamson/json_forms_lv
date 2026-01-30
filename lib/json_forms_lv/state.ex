defmodule JsonFormsLV.State do
  @moduledoc """
  Core state struct for the JSON Forms LiveView engine.
  """

  @type t :: %__MODULE__{}

  defstruct schema: %{},
            uischema: %{},
            data: nil,
            validation_mode: :validate_and_show,
            validator: nil,
            validator_opts: [],
            errors: [],
            additional_errors: [],
            touched: MapSet.new(),
            submitted: false,
            rule_state: %{},
            registry: nil,
            i18n: %{},
            readonly: false,
            raw_inputs: %{},
            opts: %{},
            schema_index: nil,
            uischema_index: nil,
            array_ids: %{}
end
