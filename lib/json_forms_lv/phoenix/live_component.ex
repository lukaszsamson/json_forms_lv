defmodule JsonFormsLV.Phoenix.LiveComponent do
  @moduledoc """
  Stateful LiveComponent wrapper for JSON Forms.

  This component owns `JsonFormsLV.State`, handles `jf:*` events, and renders
  the `json_forms` function component with `target={@myself}`.
  """

  use Phoenix.LiveComponent

  import JsonFormsLV.Phoenix.Components, only: [json_forms: 1]

  alias JsonFormsLV.{Data, Engine, Event, Limits, State}

  @impl true
  def update(assigns, socket) do
    defaults = %{
      context: %{},
      validation_mode: :validate_and_show,
      additional_errors: [],
      readonly: false,
      i18n: %{},
      binding: :per_input,
      wrap_form: true,
      renderers: [],
      control_renderers: [],
      layout_renderers: [],
      cells: [],
      opts: %{},
      on_change: "jf:change",
      on_blur: "jf:blur",
      on_submit: "jf:submit",
      notify: nil
    }

    previous = socket.assigns
    assigns = Map.merge(defaults, assigns)
    assigns = Map.delete(assigns, :streams)

    categorization_state =
      if Map.has_key?(assigns, :categorization_state) do
        assigns.categorization_state
      else
        previous[:categorization_state] || %{}
      end

    assigns = Map.put(assigns, :categorization_state, categorization_state)

    socket = assign(socket, assigns)

    state = previous[:state]

    schema_changed? = assigns[:schema] != previous[:schema]
    uischema_changed? = assigns[:uischema] != previous[:uischema]
    opts_changed? = assigns[:opts] != previous[:opts]
    data_changed? = assigns[:data] != previous[:data]

    state =
      cond do
        state == nil or schema_changed? or uischema_changed? or opts_changed? or data_changed? ->
          init_state(assigns)

        true ->
          state
      end

    state = %State{} = state

    state = %{state | readonly: assigns[:readonly] || false, i18n: assigns[:i18n] || %{}}

    state =
      maybe_set_validation_mode(state, previous[:validation_mode], assigns[:validation_mode])

    state =
      maybe_set_additional_errors(
        state,
        previous[:additional_errors],
        assigns[:additional_errors]
      )

    socket =
      socket
      |> assign(:state, state)
      |> assign(:data, state.data)

    socket = maybe_sync_array_streams(socket, state, assigns[:opts])

    {:ok, socket}
  end

  @impl true
  def handle_event("jf:change", params, socket) do
    notify = socket.assigns[:notify]

    case Event.extract_change(params) do
      {:ok, %{path: path, value: value, meta: meta}} ->
        case Engine.update_data(socket.assigns.state, path, value, meta) do
          {:ok, state} ->
            socket =
              socket
              |> assign(state: state, data: state.data)
              |> maybe_sync_array_streams(state, socket.assigns[:opts])

            notify_change(notify, state)
            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, socket}
        end

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("jf:blur", params, socket) do
    notify = socket.assigns[:notify]

    case Event.extract_blur(params) do
      {:ok, %{path: path}} ->
        {:ok, state} = Engine.touch(socket.assigns.state, path)
        socket = assign(socket, :state, state)
        notify_blur(notify, state)
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("jf:submit", _params, socket) do
    notify = socket.assigns[:notify]
    {:ok, state} = Engine.touch_all(socket.assigns.state)
    socket = assign(socket, :state, state)
    notify_submit(notify, state)
    {:noreply, socket}
  end

  def handle_event("jf:category_select", %{"key" => key, "index" => index}, socket) do
    index = normalize_index(index)
    state_map = socket.assigns[:categorization_state] || %{}
    state_map = Map.put(state_map, key, index)
    {:noreply, assign(socket, :categorization_state, state_map)}
  end

  def handle_event("jf:add_item", %{"path" => path} = params, socket) do
    opts = Map.get(params, "opts", %{})
    notify = socket.assigns[:notify]

    case Engine.add_item(socket.assigns.state, path, opts) do
      {:ok, state} ->
        socket =
          socket
          |> assign(state: state, data: state.data)
          |> maybe_sync_array_streams(state, socket.assigns[:opts])

        notify_change(notify, state)
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("jf:remove_item", %{"path" => path} = params, socket) do
    notify = socket.assigns[:notify]
    index = Map.get(params, "index") || Map.get(params, "id")

    case Engine.remove_item(socket.assigns.state, path, index) do
      {:ok, state} ->
        socket =
          socket
          |> assign(state: state, data: state.data)
          |> maybe_sync_array_streams(state, socket.assigns[:opts])

        notify_change(notify, state)
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("jf:move_item", %{"path" => path} = params, socket) do
    notify = socket.assigns[:notify]
    from = Map.get(params, "from")
    to = Map.get(params, "to")

    case Engine.move_item(socket.assigns.state, path, from, to) do
      {:ok, state} ->
        socket =
          socket
          |> assign(state: state, data: state.data)
          |> maybe_sync_array_streams(state, socket.assigns[:opts])

        notify_change(notify, state)
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.json_forms
        id={"#{@id}-form"}
        schema={@schema}
        uischema={@uischema}
        data={@data}
        state={@state}
        context={@context}
        validation_mode={@validation_mode}
        additional_errors={@additional_errors}
        readonly={@readonly}
        i18n={@i18n}
        binding={@binding}
        wrap_form={@wrap_form}
        target={@myself}
        renderers={@renderers}
        control_renderers={@control_renderers}
        layout_renderers={@layout_renderers}
        cells={@cells}
        opts={Map.put(@opts || %{}, :categorization_state, @categorization_state)}
        streams={assigns[:streams]}
        on_change={@on_change}
        on_blur={@on_blur}
        on_submit={@on_submit}
      />
    </div>
    """
  end

  defp init_state(assigns) do
    opts = assigns[:opts] || %{}
    opts = Limits.with_defaults(opts)

    case Engine.init(assigns[:schema], assigns[:uischema], assigns[:data], opts) do
      {:ok, %State{} = state} ->
        state

      {:error, _reason} ->
        %State{
          schema: assigns[:schema] || %{},
          uischema: assigns[:uischema] || %{},
          data: assigns[:data],
          opts: opts
        }
    end
  end

  defp maybe_set_validation_mode(state, previous, current) do
    if current != nil and current != previous do
      {:ok, state} = Engine.set_validation_mode(state, current)
      state
    else
      state
    end
  end

  defp maybe_set_additional_errors(state, previous, current) do
    current = current || []

    if current != previous do
      {:ok, state} = Engine.set_additional_errors(state, current)
      state
    else
      state
    end
  end

  defp maybe_sync_array_streams(socket, state, opts) do
    opts = opts || %{}

    stream_arrays? =
      Map.get(opts, :stream_arrays) == true or Map.get(opts, "stream_arrays") == true

    stream_names = Map.get(opts, :stream_names) || Map.get(opts, "stream_names") || %{}

    if stream_arrays? && is_map(stream_names) && map_size(stream_names) > 0 do
      Enum.reduce(stream_names, socket, fn {path, name}, socket ->
        items = array_stream_items(state, path, socket.assigns[:id])
        Phoenix.LiveView.stream(socket, name, items, reset: true)
      end)
    else
      socket
    end
  end

  defp array_stream_items(state, path, form_id) do
    items =
      case Data.get(state.data, path) do
        {:ok, list} when is_list(list) -> list
        _ -> []
      end

    ids = Map.get(state.array_ids || %{}, path, [])

    Enum.with_index(items)
    |> Enum.map(fn {_item, index} ->
      item_id = Enum.at(ids, index) || Integer.to_string(index)

      %{
        id: stream_dom_id(form_id || "json-forms", path, item_id),
        index: index
      }
    end)
  end

  defp stream_dom_id(form_id, path, item_id) do
    base = if path == "", do: "root", else: path

    hash =
      :crypto.hash(:sha256, form_id <> "|" <> base <> "|" <> to_string(item_id))
      |> Base.url_encode64(padding: false)

    "#{form_id}-array-#{hash}"
  end

  defp notify_change(nil, _state), do: :ok
  defp notify_change(notify, state), do: notify_event(notify, :change, state)
  defp notify_blur(nil, _state), do: :ok
  defp notify_blur(notify, state), do: notify_event(notify, :blur, state)
  defp notify_submit(nil, _state), do: :ok
  defp notify_submit(notify, state), do: notify_event(notify, :submit, state)

  defp notify_event(notify, event, state) when is_function(notify, 2) do
    notify.(event, state)
  end

  defp notify_event(notify, event, state) when is_pid(notify) do
    send(notify, {:json_forms_lv, event, state})
  end

  defp notify_event(_notify, _event, _state), do: :ok

  defp normalize_index(value) when is_integer(value), do: value

  defp normalize_index(value) when is_binary(value) do
    case Integer.parse(value) do
      {index, ""} -> index
      _ -> 0
    end
  end

  defp normalize_index(_value), do: 0
end
