defmodule JsonFormsLV.Path do
  @moduledoc """
  Utilities for converting between schema pointers, data paths, and instance paths.
  """

  @spec schema_pointer_to_data_path(String.t()) :: String.t()
  def schema_pointer_to_data_path(pointer) when pointer in ["", "#"], do: ""

  def schema_pointer_to_data_path(pointer) when is_binary(pointer) do
    pointer
    |> normalize_pointer()
    |> pointer_segments()
    |> Enum.reject(&(&1 in ["properties", "items"]))
    |> Enum.join(".")
  end

  @spec parse_data_path(String.t()) :: [String.t() | integer()]
  def parse_data_path(""), do: []

  def parse_data_path(path) when is_binary(path) do
    path
    |> String.split(".", trim: true)
    |> Enum.map(&parse_segment/1)
  end

  @spec join(String.t(), String.t()) :: String.t()
  def join("", rel_path), do: rel_path
  def join(base_path, ""), do: base_path
  def join(base_path, rel_path), do: base_path <> "." <> rel_path

  @spec data_path_to_instance_path(String.t()) :: String.t()
  def data_path_to_instance_path(""), do: ""

  def data_path_to_instance_path(path) when is_binary(path) do
    segments =
      path
      |> parse_data_path()
      |> Enum.map(&segment_to_string/1)
      |> Enum.map(&encode_pointer_segment/1)

    "/" <> Enum.join(segments, "/")
  end

  @spec instance_path_to_data_path(String.t()) :: String.t()
  def instance_path_to_data_path(""), do: ""

  def instance_path_to_data_path(path) when is_binary(path) do
    path
    |> String.trim_leading("/")
    |> pointer_segments()
    |> Enum.join(".")
  end

  defp normalize_pointer(pointer) do
    String.replace_prefix(pointer, "#", "")
  end

  defp pointer_segments(""), do: []

  defp pointer_segments(pointer) do
    pointer
    |> String.trim_leading("/")
    |> String.split("/", trim: true)
    |> Enum.map(&decode_pointer_segment/1)
  end

  defp decode_pointer_segment(segment) do
    segment
    |> String.replace("~1", "/")
    |> String.replace("~0", "~")
  end

  defp encode_pointer_segment(segment) do
    segment
    |> String.replace("~", "~0")
    |> String.replace("/", "~1")
  end

  defp parse_segment(segment) do
    case Integer.parse(segment) do
      {int, ""} -> int
      _ -> segment
    end
  end

  defp segment_to_string(segment) when is_integer(segment), do: Integer.to_string(segment)
  defp segment_to_string(segment), do: segment
end
