defmodule JsonFormsLV.LimitsTest do
  use ExUnit.Case, async: true

  alias JsonFormsLV.Limits

  test "defaults provides baseline limits" do
    defaults = Limits.defaults()

    assert defaults.max_elements == 1_000
    assert defaults.max_depth == 30
    assert defaults.max_errors == 100
    assert defaults.max_data_bytes == 1_000_000
  end

  test "with_defaults merges overrides" do
    opts = Limits.with_defaults(%{max_depth: 12})

    assert opts.max_depth == 12
    assert opts.max_elements == 1_000
  end
end
