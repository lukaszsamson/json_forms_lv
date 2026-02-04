defmodule JsonFormsLV.Phoenix.StreamSync do
  @moduledoc """
  Helpers to synchronize LiveView streams for array controls.
  """

  alias JsonFormsLV.{Data, State}

  @spec sync(Phoenix.LiveView.Socket.t(), State.t() | nil, State.t() | nil, map() | keyword()) ::
          Phoenix.LiveView.Socket.t()
  def sync(socket, old_state, new_state, opts) do
    opts = normalize_opts(opts)

    stream_arrays? =
      Map.get(opts, :stream_arrays) == true or Map.get(opts, "stream_arrays") == true

    stream_names = Map.get(opts, :stream_names) || Map.get(opts, "stream_names") || %{}

    cond do
      not stream_arrays? ->
        socket

      not is_map(stream_names) or map_size(stream_names) == 0 ->
        socket

      not match?(%State{}, new_state) ->
        socket

      true ->
        form_id = Map.get(opts, :form_id) || Map.get(opts, "form_id") || "json-forms"
        dom_id_fun = dom_id_fun(opts, form_id)

        Enum.reduce(stream_names, socket, fn {path, name}, socket ->
          old_items = array_items(old_state, path)
          new_items = array_items(new_state, path)
          old_ids = array_ids(old_state, path, old_items)
          new_ids = array_ids(new_state, path, new_items)
          old_dom_ids = Enum.map(old_ids, &dom_id_fun.(path, &1))
          new_dom_ids = Enum.map(new_ids, &dom_id_fun.(path, &1))

          entries = build_entries(path, new_ids, dom_id_fun)
          stream_defined? = stream_defined?(socket, name)

          if match?(%State{}, old_state) and stream_defined? do
            removed = old_dom_ids -- new_dom_ids
            added = new_dom_ids -- old_dom_ids
            # Detect reordering: same items but different order
            reordered? =
              removed == [] and added == [] and old_dom_ids != new_dom_ids

            cond do
              reordered? ->
                # When items are reordered, reset stream to apply new order
                Phoenix.LiveView.stream(socket, name, entries, reset: true)

              removed != [] or added != [] ->
                # Items added or removed - update incrementally
                socket =
                  Enum.reduce(removed, socket, fn dom_id, socket ->
                    Phoenix.LiveView.stream_delete(socket, name, %{id: dom_id})
                  end)

                Enum.reduce(Enum.with_index(entries), socket, fn {entry, index}, socket ->
                  Phoenix.LiveView.stream_insert(socket, name, entry, at: index)
                end)

              true ->
                socket
            end
          else
            Phoenix.LiveView.stream(socket, name, entries, reset: true)
          end
        end)
    end
  end

  defp normalize_opts(nil), do: %{}
  defp normalize_opts(opts) when is_map(opts), do: opts
  defp normalize_opts(opts) when is_list(opts), do: Map.new(opts)

  defp array_items(%State{} = state, path) do
    case Data.get(state.data, path) do
      {:ok, items} when is_list(items) -> items
      _ -> []
    end
  end

  defp array_items(_state, _path), do: []

  defp array_ids(%State{} = state, path, items) do
    ids = Map.get(state.array_ids || %{}, path, [])

    if length(ids) == length(items) do
      ids
    else
      index_ids(items)
    end
  end

  defp array_ids(_state, _path, items), do: index_ids(items)

  defp stream_defined?(socket, name) do
    case socket.assigns do
      %{streams: streams} when is_map(streams) -> Map.has_key?(streams, name)
      _ -> false
    end
  end

  defp index_ids([]), do: []

  defp index_ids(items) when is_list(items) do
    Enum.map(0..(length(items) - 1), &Integer.to_string/1)
  end

  defp dom_id_fun(opts, form_id) do
    case Map.get(opts, :stream_dom_id) || Map.get(opts, "stream_dom_id") do
      fun when is_function(fun, 2) -> fun
      fun when is_function(fun, 3) -> fn path, item_id -> fun.(form_id, path, item_id) end
      fun when is_function(fun, 1) -> fn path, item_id -> fun.({path, item_id}) end
      _ -> fn path, item_id -> default_stream_dom_id(form_id, path, item_id) end
    end
  end

  defp build_entries(path, ids, dom_id_fun) do
    ids
    |> Enum.with_index()
    |> Enum.map(fn {item_id, index} ->
      %{
        id: dom_id_fun.(path, item_id),
        index: index
      }
    end)
  end

  defp default_stream_dom_id(form_id, path, item_id) do
    base = if path == "", do: "root", else: path

    hash =
      :crypto.hash(:sha256, form_id <> "|" <> base <> "|" <> to_string(item_id))
      |> Base.url_encode64(padding: false)

    "#{form_id}-array-#{hash}"
  end
end
