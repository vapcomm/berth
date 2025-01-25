defmodule BerthTest do
  use ExUnit.Case
  doctest Berth

  test "greets the world" do
    assert Berth.hello() == :world
  end
end
