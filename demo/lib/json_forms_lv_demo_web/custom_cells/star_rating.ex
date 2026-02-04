defmodule JsonFormsLvDemoWeb.CustomCells.StarRating do
  @moduledoc """
  Custom star rating cell for integer fields.
  Renders 5 clickable stars for rating selection.
  """

  use Phoenix.Component

  alias JsonFormsLV.Testers

  @behaviour JsonFormsLV.Renderer

  @impl JsonFormsLV.Renderer
  def tester(uischema, schema, ctx) do
    Testers.rank_with(
      30,
      Testers.all_of([
        Testers.schema_type_is("integer"),
        Testers.has_option("format", "rating")
      ])
    ).(uischema, schema, ctx)
  end

  @impl JsonFormsLV.Renderer
  def render(assigns) do
    value = assigns.value || 0
    max_stars = 5

    assigns =
      assign(assigns,
        value: value,
        max_stars: max_stars,
        stars: 1..max_stars,
        disabled?: disabled?(assigns)
      )

    ~H"""
    <div class="jf-star-rating" id={@id}>
      <div class="jf-stars" role="radiogroup" aria-label="Rating">
        <%= for star <- @stars do %>
          <button
            type="button"
            class={["jf-star-btn", star <= @value && "jf-star-filled"]}
            disabled={@disabled?}
            aria-label={"#{star} star#{if star > 1, do: "s", else: ""}"}
            aria-pressed={star <= @value}
            phx-click="jf:star_click"
            phx-value-path={@path}
            phx-value-rating={star}
            phx-target={@target}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill={if star <= @value, do: "currentColor", else: "none"}
              stroke="currentColor"
              stroke-width="1.5"
              class="jf-star-icon"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z"
              />
            </svg>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp disabled?(assigns) do
    not assigns.enabled? or assigns.readonly?
  end
end
