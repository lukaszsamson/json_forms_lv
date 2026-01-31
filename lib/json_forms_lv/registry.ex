defmodule JsonFormsLV.Registry do
  @moduledoc """
  Registry of renderer modules.

  Renderers are stored by category and selected by tester rank. You can
  extend a registry with custom renderers or cells before rendering.

  ## Examples

      registry = Registry.new()
      registry = Registry.register_control(registry, MyControlRenderer)
      registry = Registry.register_cells(registry, [MyCell])
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

  @doc """
  Create a new registry from lists of renderers.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      control_renderers: normalize_entries(Keyword.get(opts, :control_renderers, [])),
      layout_renderers: normalize_entries(Keyword.get(opts, :layout_renderers, [])),
      cell_renderers: normalize_entries(Keyword.get(opts, :cell_renderers, []))
    }
  end

  @doc """
  Register a single control renderer with highest priority.
  """
  @spec register_control(t(), entry()) :: t()
  def register_control(%__MODULE__{} = registry, entry) do
    %__MODULE__{registry | control_renderers: [entry | registry.control_renderers]}
  end

  @doc """
  Register a single layout renderer with highest priority.
  """
  @spec register_layout(t(), entry()) :: t()
  def register_layout(%__MODULE__{} = registry, entry) do
    %__MODULE__{registry | layout_renderers: [entry | registry.layout_renderers]}
  end

  @doc """
  Register a single cell renderer with highest priority.
  """
  @spec register_cell(t(), entry()) :: t()
  def register_cell(%__MODULE__{} = registry, entry) do
    %__MODULE__{registry | cell_renderers: [entry | registry.cell_renderers]}
  end

  @doc """
  Remove a control renderer by module.
  """
  @spec remove_control(t(), module()) :: t()
  def remove_control(%__MODULE__{} = registry, module) when is_atom(module) do
    %__MODULE__{registry | control_renderers: remove_entries(registry.control_renderers, module)}
  end

  @doc """
  Remove a layout renderer by module.
  """
  @spec remove_layout(t(), module()) :: t()
  def remove_layout(%__MODULE__{} = registry, module) when is_atom(module) do
    %__MODULE__{registry | layout_renderers: remove_entries(registry.layout_renderers, module)}
  end

  @doc """
  Remove a cell renderer by module.
  """
  @spec remove_cell(t(), module()) :: t()
  def remove_cell(%__MODULE__{} = registry, module) when is_atom(module) do
    %__MODULE__{registry | cell_renderers: remove_entries(registry.cell_renderers, module)}
  end

  @doc """
  Register multiple control renderers with highest priority.
  """
  @spec register_controls(t(), [entry()]) :: t()
  def register_controls(%__MODULE__{} = registry, entries) do
    entries = normalize_entries(entries)
    %__MODULE__{registry | control_renderers: entries ++ registry.control_renderers}
  end

  @doc """
  Register multiple layout renderers with highest priority.
  """
  @spec register_layouts(t(), [entry()]) :: t()
  def register_layouts(%__MODULE__{} = registry, entries) do
    entries = normalize_entries(entries)
    %__MODULE__{registry | layout_renderers: entries ++ registry.layout_renderers}
  end

  @doc """
  Register multiple cell renderers with highest priority.
  """
  @spec register_cells(t(), [entry()]) :: t()
  def register_cells(%__MODULE__{} = registry, entries) do
    entries = normalize_entries(entries)
    %__MODULE__{registry | cell_renderers: entries ++ registry.cell_renderers}
  end

  @doc """
  Merge custom renderers ahead of defaults.
  """
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

  defp remove_entries(entries, module) do
    Enum.reject(entries, fn entry -> entry_module(entry) == module end)
  end

  defp entry_module({module, _opts}) when is_atom(module), do: module
  defp entry_module(module) when is_atom(module), do: module
  defp entry_module(_entry), do: nil
end
