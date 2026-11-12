defmodule Paclog do
  @moduledoc """
  Reads and parses pacman logs.
  """

  alias Paclog.{Parser, Zone}

  @default_path "/var/log/pacman.log"

  def main(args) do
    case args do
      [] -> print_entries(@default_path)
      [path] -> print_entries(path)
      _ -> IO.puts(:stderr, "Usage: paclog [log_path]")
    end
  end

  defp print_entries(path) do
    zone = Zone.local()

    path
    |> File.stream!()
    |> Stream.map(&Parser.parse(&1, zone))
    |> Stream.flat_map(fn
      {:ok, entry} -> [entry]
      :skip -> []
    end)
    |> Enum.take(5)
    |> IO.inspect(pretty: true, limit: :infinity)
  end
end
