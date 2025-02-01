defmodule Berth do
  @moduledoc """
  Berth is a cache server for a S3 storage
  """

  use Application
  require Logger

  @impl true
  def start(type, args) do
    sys_args = OptionParser.parse(System.argv(), strict: [config: :string])
    Logger.notice("Application: start: type: #{inspect(type)}, args: #{inspect(args)}, sys_args: #{inspect(sys_args)}")

    children = [
      Berth.BlobCache,  #TODO: cache size from config
      {Bandit, plug: Berth.MainRouter, port: 8080}  # module spec
    ]

    opts = [strategy: :one_for_one, name: Berth.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def stop(arg) do
    Logger.notice("Application: stop: arg: #{inspect(arg)}")
  end

end
