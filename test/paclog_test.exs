defmodule PaclogTest do
  use ExUnit.Case
  doctest Paclog

  test "greets the world" do
    assert Paclog.hello() == :world
  end
end
