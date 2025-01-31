defmodule Berth.MixProject do
  use Mix.Project

  def project do
    [
      app: :berth,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      preferred_cli_env: [release: :prod],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Berth, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, ">= 1.6.6"},
      {:plug, ">= 1.16.1"}
    ]
  end

end
