defmodule AliceHashtag.Mixfile do
  use Mix.Project

  def project do
    [app: :alice_hashtag,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: "Keep track of hashtags used in rooms where Alice is present",
     package: package,
     deps: deps]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [
      {:websocket_client, github: "jeremyong/websocket_client"},
      {:alice, "~> 0.3"}
    ]
  end

  defp package do
    [files: ["lib", "config", "mix.exs", "README*"],
     maintainers: ["Adam Zaninovich"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/alice-bot/alice_hashtag"}]
  end
end
