defmodule Paclog.Entry do
  @moduledoc "Reads line from `pacman.log` and creates struct from information."

  @doc "define different action types for packages"
  @type action :: :installed | :upgraded | :downgraded | :removed | :reinstalled

  @type t :: %__MODULE__{
          time: DateTime.t() | NaiveDateTime.t(),
          src: String.t(),
          action: action(),
          pkg: String.t(),
          old: String.t() | nil,
          new: String.t() | nil,
          raw: String.t()
        }

  @enforce_keys [:time, :src, :action, :pkg]

  defstruct [:time, :src, :action, :pkg, :old, :new, :raw]
end
