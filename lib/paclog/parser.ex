defmodule Paclog.Parser do
  @moduledoc """
  Parses information in a given entry from pacman.log into format from Entry.ex
  """

  alias Tz.TimeZoneDatabase
  alias Paclog.Entry

  @line ~r/^\[(.+?)\] \[(.+?)\] (.*)$/

  @spec parse(String.t(), String.t()) :: {:ok, Entry.t()} | :skip
  def parse(line, zone) do
    line = String.trim_trailing(line)

    with [_, ts, src, msg] <- Regex.run(@line, line),
         {:ok, time} <- parse_time(ts, zone),
         {:ok, fields} <- parse_action(msg) do
      {:ok, struct!(Entry, Map.merge(fields, %{time: time, src: src, raw: line}))}
    else
      _ -> :skip
    end
  end

  defp parse_action("upgraded " <> rest), do: version_change(:upgraded, rest)
  defp parse_action("downgraded " <> rest), do: version_change(:downgraded, rest)
  defp parse_action("installed " <> rest), do: single_version(:installed, rest)
  defp parse_action("removed " <> rest), do: single_version(:removed, rest)
  defp parse_action("reinstalled " <> rest), do: single_version(:reinstalled, rest)
  defp parse_action(_), do: :skip

  defp extract_pkg_ver(rest) do
    with [pkg, inner] <- String.split(rest, " (", parts: 2) do
      inner = String.trim_trailing(inner, ")")
      {:ok, pkg, inner}
    else
      _ -> :error
    end
  end

  defp version_change(action, rest) do
    with {:ok, pkg, inner} <- extract_pkg_ver(rest),
         [old, new] <- String.split(inner, " -> ", parts: 2) do
      {:ok, %{action: action, pkg: pkg, old: old, new: new}}
    else
      _ -> :skip
    end
  end

  defp single_version(action, rest) do
    with {:ok, pkg, inner} <- extract_pkg_ver(rest) do
      fields =
        case action do
          :removed -> %{action: action, pkg: pkg, old: inner}
          _ -> %{action: action, pkg: pkg, new: inner}
        end

      {:ok, fields}
    else
      _ -> :skip
    end
  end

  defp parse_time(ts, zone) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _offset} -> {:ok, dt}
      {:error, _} -> parse_old_time(ts, zone)
    end
  end

  defp parse_old_time(ts, zone) do
    with {:ok, naive} <- NaiveDateTime.from_iso8601(ts <> ":00"),
         {:ok, local} <- from_local(naive, zone),
         {:ok, utc} <- DateTime.shift_zone(local, "Etc/UTC", TimeZoneDatabase) do
      {:ok, utc}
    else
      _ -> :error
    end
  end

  defp from_local(naive, zone) do
    case DateTime.from_naive(naive, zone) do
      {:ok, dt} -> {:ok, dt}
      {:ambiguous, time, _} -> {:ok, time}
      {:gap, _, time} -> {:ok, time}
      {:error, _} -> :error
    end
  end
end
