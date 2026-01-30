defmodule JsonFormsLV.Dispatch do
  @moduledoc """
  Renderer selection based on tester ranks.
  """

  alias JsonFormsLV.Registry

  @spec kind_for_uischema(map()) :: :control | :layout | :unknown
  def kind_for_uischema(%{"type" => "Control"}), do: :control

  def kind_for_uischema(%{"type" => type})
      when type in [
             "VerticalLayout",
             "HorizontalLayout",
             "Group",
             "Label",
             "Categorization",
             "Category"
           ] do
    :layout
  end

  def kind_for_uischema(%{"type" => _type}), do: :unknown
  def kind_for_uischema(_), do: :unknown

  @spec pick_renderer(map(), map() | nil, Registry.t(), map(), atom()) ::
          {module(), keyword()} | nil
  def pick_renderer(uischema, schema, %Registry{} = registry, ctx, kind) do
    entries =
      case kind do
        :control -> registry.control_renderers
        :layout -> registry.layout_renderers
        :cell -> registry.cell_renderers
        _ -> []
      end

    select_best(entries, uischema, schema, ctx)
  end

  defp select_best(entries, uischema, schema, ctx) do
    {best_entry, _best_rank, _best_index} =
      Enum.with_index(entries)
      |> Enum.reduce({nil, -1, nil}, fn {entry, index}, {best, best_rank, best_index} ->
        {module, opts} = normalize_entry(entry)

        case safe_tester(module, uischema, schema, ctx) do
          :not_applicable ->
            {best, best_rank, best_index}

          rank when is_integer(rank) ->
            cond do
              rank > best_rank ->
                {{module, opts}, rank, index}

              rank == best_rank and (best_index == nil or index < best_index) ->
                {{module, opts}, rank, index}

              true ->
                {best, best_rank, best_index}
            end

          _ ->
            {best, best_rank, best_index}
        end
      end)

    best_entry
  end

  defp safe_tester(module, uischema, schema, ctx) do
    module.tester(uischema, schema, ctx)
  rescue
    _ -> :not_applicable
  end

  defp normalize_entry({module, opts}) when is_list(opts), do: {module, opts}
  defp normalize_entry(module) when is_atom(module), do: {module, []}
  defp normalize_entry(_), do: {nil, []}
end
