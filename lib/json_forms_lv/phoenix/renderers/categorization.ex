defmodule JsonFormsLV.Phoenix.Renderers.Categorization do
  @moduledoc """
  Renderer for Categorization UISchema elements.
  """

  use Phoenix.Component

  import JsonFormsLV.Phoenix.Components, only: [dispatch: 1]

  alias JsonFormsLV.{I18n, Rules}
  alias Phoenix.LiveView.JS

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(%{"type" => "Categorization"}, _schema, _ctx), do: 10
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    categories = Map.get(assigns.uischema, "elements", [])
    options = Map.get(assigns.uischema, "options", %{})
    state_map = categorization_state(assigns)
    persist_tabs? = is_map(state_map)

    # Compute visibility for each category based on rules
    visible_categories =
      categories
      |> Enum.with_index()
      |> Enum.filter(fn {category, index} ->
        category_visible?(category, index, assigns)
      end)

    default_index = default_visible_index(options, visible_categories)
    active_index = active_index(state_map, assigns.render_key, default_index, visible_categories)

    assigns =
      assigns
      |> assign(:categories, Enum.with_index(categories))
      |> assign(:visible_categories, visible_categories)
      |> assign(:default_index, default_index)
      |> assign(:active_index, active_index)
      |> assign(:persist_tabs?, persist_tabs?)

    ~H"""
    <%= if @visible? do %>
      <div id={@id} data-jf-layout="categorization" class="jf-layout jf-categorization">
        <div role="tablist" class="jf-categorization-tabs">
          <%= for {category, index} <- @visible_categories do %>
            <button
              id={tab_id(@id, index)}
              type="button"
              role="tab"
              aria-controls={panel_id(@id, index)}
              aria-selected={if index == @active_index, do: "true", else: "false"}
              tabindex={if index == @active_index, do: "0", else: "-1"}
              phx-click={tab_js(@id, @visible_categories, index, @persist_tabs?, @render_key, @target)}
              disabled={not @enabled? or @readonly?}
            >
              {category_label(category, index, @i18n, @ctx)}
            </button>
          <% end %>
        </div>
        <div class="jf-categorization-panels">
          <%= for {category, index} <- @visible_categories do %>
            <div
              id={panel_id(@id, index)}
              role="tabpanel"
              aria-labelledby={tab_id(@id, index)}
              class="jf-category-panel"
              style={if index != @active_index, do: "display: none;"}
            >
              <.dispatch
                state={@state}
                registry={@registry}
                uischema={category}
                data={@data}
                form_id={@form_id}
                binding={@binding}
                streams={@streams}
                path={@path}
                element_path={(@element_path || []) ++ [index]}
                depth={@depth + 1}
                on_change={@on_change}
                on_blur={@on_blur}
                on_submit={@on_submit}
                target={@target}
                config={@config}
                context={
                  Map.merge(@context || %{}, %{
                    parent_uischema_type: "Categorization",
                    categorization_ancestor?: true
                  })
                }
                parent_visible?={@visible?}
                parent_enabled?={@enabled?}
              />
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  defp category_visible?(category, index, assigns) do
    element_path = (assigns.element_path || []) ++ [index]
    element_key = Rules.element_key(category, element_path)
    render_key = Rules.render_key(element_key, assigns.path || "")
    rule_state = assigns.state.rule_state || %{}
    flags = Map.get(rule_state, render_key, %{visible?: true})
    Map.get(flags, :visible?, true)
  end

  defp category_label(category, index, i18n, ctx) do
    {label, show_label?} = resolve_label(category)
    label = I18n.translate_label(label, i18n, ctx)

    cond do
      not show_label? -> nil
      is_binary(label) and label != "" -> label
      true -> "Category #{index + 1}"
    end
  end

  defp resolve_label(%{"label" => false}), do: {nil, false}
  defp resolve_label(%{"label" => %{"show" => false}}), do: {nil, false}

  defp resolve_label(%{"label" => %{"show" => true, "text" => text}}) when is_binary(text),
    do: {text, true}

  defp resolve_label(%{"label" => label}) when is_binary(label), do: {label, true}
  defp resolve_label(_), do: {nil, true}

  defp tab_id(base_id, index), do: "#{base_id}-tab-#{index}"
  defp panel_id(base_id, index), do: "#{base_id}-panel-#{index}"

  defp tab_js(base_id, visible_categories, active_index, persist_tabs?, render_key, target) do
    panel_ids =
      Enum.map(visible_categories, fn {_category, index} -> panel_id(base_id, index) end)

    tab_ids = Enum.map(visible_categories, fn {_category, index} -> tab_id(base_id, index) end)

    active_panel = panel_id(base_id, active_index)
    active_tab = tab_id(base_id, active_index)

    %JS{}
    |> toggle_panels(panel_ids, active_panel)
    |> toggle_tabs(tab_ids, active_tab)
    |> maybe_push_tab(persist_tabs?, render_key, active_index, target)
  end

  defp toggle_panels(js, panel_ids, active_panel) do
    Enum.reduce(panel_ids, js, fn panel_id, js ->
      if panel_id == active_panel do
        JS.show(js, to: "##{panel_id}")
      else
        JS.hide(js, to: "##{panel_id}")
      end
    end)
  end

  defp toggle_tabs(js, tab_ids, active_tab) do
    Enum.reduce(tab_ids, js, fn tab_id, js ->
      if tab_id == active_tab do
        js
        |> JS.set_attribute({"aria-selected", "true"}, to: "##{tab_id}")
        |> JS.set_attribute({"tabindex", "0"}, to: "##{tab_id}")
      else
        js
        |> JS.set_attribute({"aria-selected", "false"}, to: "##{tab_id}")
        |> JS.set_attribute({"tabindex", "-1"}, to: "##{tab_id}")
      end
    end)
  end

  defp maybe_push_tab(js, true, render_key, index, target) do
    JS.push(js, "jf:category_select", value: %{key: render_key, index: index}, target: target)
  end

  defp maybe_push_tab(js, _persist?, _render_key, _index, _target), do: js

  defp categorization_state(assigns) do
    config = assigns.config || %{}

    Map.get(config, :categorization_state) || Map.get(config, "categorization_state")
  end

  defp active_index(state_map, render_key, default_index, visible_categories)
       when is_map(state_map) and is_binary(render_key) do
    stored_index =
      case Map.fetch(state_map, render_key) do
        {:ok, index} when is_integer(index) -> index
        {:ok, index} when is_binary(index) -> parse_index(index, nil)
        _ -> nil
      end

    # Check if stored index is among visible categories
    visible_indices = Enum.map(visible_categories, fn {_cat, idx} -> idx end)

    cond do
      stored_index != nil and stored_index in visible_indices -> stored_index
      default_index in visible_indices -> default_index
      visible_indices != [] -> hd(visible_indices)
      true -> 0
    end
  end

  defp active_index(_state_map, _render_key, default_index, visible_categories) do
    visible_indices = Enum.map(visible_categories, fn {_cat, idx} -> idx end)

    cond do
      default_index in visible_indices -> default_index
      visible_indices != [] -> hd(visible_indices)
      true -> 0
    end
  end

  defp parse_index(value, fallback) do
    case Integer.parse(value) do
      {index, ""} -> index
      _ -> fallback
    end
  end

  defp default_visible_index(options, visible_categories) do
    raw = Map.get(options || %{}, "defaultCategory")
    visible_indices = Enum.map(visible_categories, fn {_cat, idx} -> idx end)

    requested_index =
      cond do
        is_integer(raw) ->
          raw

        is_binary(raw) ->
          case Integer.parse(raw) do
            {value, ""} -> value
            _ -> 0
          end

        true ->
          0
      end

    cond do
      visible_indices == [] -> 0
      requested_index in visible_indices -> requested_index
      true -> hd(visible_indices)
    end
  end
end
