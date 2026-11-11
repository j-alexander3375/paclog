defmodule Paclog.Zone do
  @moduledoc """
  Gets user's timezone for use in parser.
  """
  
  @fallback "Etc/UTC"
  @local_time "/etc/localtime"

  @spec local() :: String.t()
  def local do
    with :error <- from_env(),
         :error <- from_localtime() do
      @fallback
    else
      {:ok, zone} -> zone
    end
  end

  @spec from_env() :: {:ok, String.t()} | :error
  defp from_env do
    zone_from_env(System.get_env("TZ"))
  end

  @spec from_localtime() :: {:ok, String.t()} | :error
  defp from_localtime do
    zone_from_localtime(@local_time)
  end

  @doc false
  @spec zone_from_env(String.t() | nil) :: {:ok, String.t()} | :error
  def zone_from_env(nil), do: :error

  def zone_from_env(env) do
    zone = String.trim_leading(env, ":")

    if valid?(zone), do: {:ok, zone}, else: :error
  end

  @doc false
  @spec zone_from_localtime(String.t()) :: {:ok, String.t()} | :error
  def zone_from_localtime(local) do
    with {:ok, target} <- File.read_link(local),
         path <- Path.expand(target, Path.dirname(local)),
         [_, zone] <- String.split(path, "/zoneinfo/", parts: 2) do
      zone_from_env(zone)
    else
      _ -> :error
    end
  end

  @spec valid?(String.t()) :: boolean()
  def valid?(zone) do
    case DateTime.now(zone) do
      {:ok, _datetime} -> true
      {:error, _reason} -> false
    end
  end
end
