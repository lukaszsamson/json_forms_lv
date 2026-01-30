defmodule JsonFormsLV.Registry do
  @moduledoc """
  Registry of renderer modules.
  """

  @type entry :: module() | {module(), keyword()}

  defstruct control_renderers: [],
            layout_renderers: [],
            cell_renderers: []

  @type t :: %__MODULE__{
          control_renderers: [entry()],
          layout_renderers: [entry()],
          cell_renderers: [entry()]
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      control_renderers: normalize_entries(Keyword.get(opts, :control_renderers, [])),
      layout_renderers: normalize_entries(Keyword.get(opts, :layout_renderers, [])),
      cell_renderers: normalize_entries(Keyword.get(opts, :cell_renderers, []))
    }
  end

  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = custom, %__MODULE__{} = defaults) do
    %__MODULE__{
      control_renderers: custom.control_renderers ++ defaults.control_renderers,
      layout_renderers: custom.layout_renderers ++ defaults.layout_renderers,
      cell_renderers: custom.cell_renderers ++ defaults.cell_renderers
    }
  end

  defp normalize_entries(entries) when is_list(entries), do: entries
  defp normalize_entries(_entries), do: []
end
