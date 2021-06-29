defmodule Emotes4Test do
  use ExUnit.Case
  doctest Emotes4

  test "greets the world" do
    assert Emotes4.hello() == :world
  end
end
