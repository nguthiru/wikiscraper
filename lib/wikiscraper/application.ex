defmodule Wikiscraper.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: Wikiscraper.TaskSupervisor, strategy: :one_for_one},

    ]
    IO.inspect("STARTING WITH APPLICATION")

    opts = [strategy: :one_for_one, name: Wikiscraper.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
