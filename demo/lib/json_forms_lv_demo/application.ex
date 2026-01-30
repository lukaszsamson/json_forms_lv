defmodule JsonFormsLvDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      JsonFormsLvDemoWeb.Telemetry,
      {DNSCluster,
       query: Application.get_env(:json_forms_lv_demo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: JsonFormsLvDemo.PubSub},
      # Start a worker by calling: JsonFormsLvDemo.Worker.start_link(arg)
      # {JsonFormsLvDemo.Worker, arg},
      # Start to serve requests, typically the last entry
      JsonFormsLvDemoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JsonFormsLvDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JsonFormsLvDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
