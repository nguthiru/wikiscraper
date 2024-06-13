defmodule WikiscraperTest do
  use ExUnit.Case
  doctest Wikiscraper

  test "greets the world" do
    assert Wikiscraper.hello() == :world
  end
end
