defmodule JsonFormsLV.Telemetry do
  @moduledoc """
  Telemetry events emitted by JsonFormsLV.

  ## Events

  ### `[:json_forms_lv, :init]`

  Emitted when `JsonFormsLV.Engine.init/4` completes.

  Measurements:

    * `:duration`

  Metadata:

    * `:validation_mode`

  ### `[:json_forms_lv, :update_data]`

  Emitted after `JsonFormsLV.Engine.update_data/4` updates state.

  Measurements:

    * `:duration`

  Metadata:

    * `:path`
    * `:result`

  ### `[:json_forms_lv, :validate]`

  Emitted after validation completes.

  Measurements:

    * `:duration`

  Metadata:

    * `:error_count`

  ### `[:json_forms_lv, :dispatch]`

  Emitted when a renderer is selected.

  Measurements:

    * `:duration`

  Metadata:

    * `:kind`
    * `:renderer`
    * `:uischema_type`
    * `:schema_type`
    * `:path`
  """
end
