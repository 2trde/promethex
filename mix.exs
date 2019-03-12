defmodule Promethex.MixProject do
  use Mix.Project

  def project do
    [
      app: :promethex,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_paths: ["lib"],
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:meck, "~> 0.8.5"},
      {:httpoison, "~> 1.5"}
    ]
  end
end
