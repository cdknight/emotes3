defmodule Emotes4.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Emotes4.Worker.start_link(arg)
      # {Emotes4.Worker, arg}
      {Plug.Cowboy, scheme: :http, plug: Emotes4.WebApplication, options: [port: 8080]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Emotes4.Supervisor]

    Logger.info("hello")
    Supervisor.start_link(children, opts)
  end
end
