defmodule JsonFormsLV.MixProject do
  use Mix.Project

  def project do
    [
      app: :json_forms_lv,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      name: "JsonFormsLV",
      description: "Server-side JSON Forms 3.x renderer for Phoenix LiveView",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.8.3"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.1.0"},
      {:jsv, "~> 0.16"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "SPEC_V1.md"],
      groups_for_modules: [
        Core: [
          JsonFormsLV.Engine,
          JsonFormsLV.State,
          JsonFormsLV.Data,
          JsonFormsLV.Path,
          JsonFormsLV.Schema,
          JsonFormsLV.Rules,
          JsonFormsLV.Coercion
        ],
        Validation: [JsonFormsLV.Validator, JsonFormsLV.Errors],
        Rendering: [
          JsonFormsLV.Dispatch,
          JsonFormsLV.Registry,
          JsonFormsLV.Renderer,
          JsonFormsLV.Testers
        ],
        Phoenix: ~r/JsonFormsLV\.Phoenix\./,
        "Built-in Renderers": ~r/JsonFormsLV\.Phoenix\.Renderers\./,
        "Built-in Cells": ~r/JsonFormsLV\.Phoenix\.Cells\./
      ]
    ]
  end
end
