defmodule JsonFormsLV.Phoenix.Cells.BooleanInput do
  @moduledoc """
  Cell renderer for boolean inputs.
  """

  use Phoenix.Component

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(_uischema, %{"type" => "boolean"}, _ctx), do: 10
  def tester(_uischema, _schema, _ctx), do: :not_applicable

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    change_event = if assigns.binding == :per_input, do: assigns.on_change
    blur_event = assigns.on_blur
    toggle? = Map.get(assigns.options || %{}, "toggle") == true
    role = if toggle?, do: "switch"
    aria_checked = if toggle?, do: to_string(assigns.value == true)
    locale = locale(assigns)

    assigns =
      assign(assigns,
        checked?: assigns.value == true,
        disabled?: disabled?(assigns),
        change_event: change_event,
        blur_event: blur_event,
        toggle?: toggle?,
        role: role,
        aria_checked: aria_checked,
        locale: locale,
        aria_describedby: assigns[:aria_describedby],
        aria_invalid: assigns[:aria_invalid],
        aria_required: assigns[:aria_required]
      )

    ~H"""
    <input type="hidden" name={@path} value="false" disabled={@disabled?} />
    <input
      id={@id}
      name={@path}
      type="checkbox"
      value="true"
      checked={@checked?}
      disabled={@disabled?}
      role={@role}
      aria-checked={@aria_checked}
      data-jf-toggle={@toggle?}
      lang={@locale}
      aria-describedby={@aria_describedby}
      aria-invalid={@aria_invalid}
      aria-required={@aria_required}
      phx-change={@change_event}
      phx-blur={@blur_event}
      phx-target={@target}
    />
    """
  end

  defp disabled?(assigns) do
    not assigns.enabled? or assigns.readonly?
  end

  defp locale(assigns) do
    Map.get(assigns.i18n || %{}, :locale) || Map.get(assigns.i18n || %{}, "locale")
  end
end
