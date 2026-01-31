defmodule JsonFormsLV.UISchema do
  @moduledoc """
  Generate default UISchema layouts from JSON Schema.
  """

  @spec default(map()) :: map()
  def default(schema) when is_map(schema) do
    if object_schema?(schema) and is_map(schema["properties"]) do
      properties = schema["properties"] || %{}

      %{
        "type" => "VerticalLayout",
        "elements" =>
          properties
          |> Map.keys()
          |> Enum.sort()
          |> Enum.map(&control_for_property/1)
      }
    else
      %{"type" => "Control", "scope" => "#"}
    end
  end

  def default(_schema), do: %{"type" => "Control", "scope" => "#"}

  defp object_schema?(%{"type" => "object"}), do: true
  defp object_schema?(%{"properties" => props}) when is_map(props), do: true
  defp object_schema?(_schema), do: false

  defp control_for_property(key) do
    %{"type" => "Control", "scope" => "#/properties/#{encode_pointer_segment(key)}"}
  end

  defp encode_pointer_segment(key) when is_binary(key) do
    key
    |> String.replace("~", "~0")
    |> String.replace("/", "~1")
  end

  defp encode_pointer_segment(key), do: key |> to_string() |> encode_pointer_segment()
end
