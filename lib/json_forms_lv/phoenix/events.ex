defmodule JsonFormsLV.Phoenix.Events do
  @moduledoc """
  Helpers for extracting form-level binding events from LiveView params.
  """

  alias JsonFormsLV.Event

  @spec extract_form_change(map(), keyword()) ::
          {:ok, %{path: String.t(), value: term(), meta: map()}} | {:error, term()}
  def extract_form_change(params, opts \\ []) do
    Event.extract_change(params, opts)
  end

  @spec extract_form_blur(map(), keyword()) ::
          {:ok, %{path: String.t(), meta: map()}} | {:error, term()}
  def extract_form_blur(params, opts \\ []) do
    Event.extract_blur(params, opts)
  end
end
