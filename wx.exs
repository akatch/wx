#!/bin/elixir

## wx: a METAR parser written in Elixir
# (c) 2023 Al Bowles

Mix.install([
  {:req, "~> 0.3.4"}
])

defmodule Wx do
  def main(_args) do
    output = parse(metar())
    IO.inspect(output)
  end

  def parse(metar_string) do
    %{"temperature" => t, "dewpoint" => dp} =
      Regex.named_captures(
        ~r/\s(?<temperature>M?(\d{2}))\/(?<dewpoint>M?(\d{2}))\s/,
        metar_string
      )

    temperature =
      case t do
        "M" <> rest -> -String.to_integer(rest)
        _ -> String.to_integer(t)
      end

    dewpoint =
      case dp do
        "M" <> rest -> -String.to_integer(rest)
        _ -> String.to_integer(dp)
      end

    %{temperature: temperature, dewpoint: dewpoint}
  end

  def metar() do
    Req.get!("https://tgftp.nws.noaa.gov/data/observations/metar/stations/KMDW.TXT").body
  end
end

case System.argv() do
  # if the first arg (after the filename) is "test", run these tests
  ["test"] ->
    ExUnit.start()

    defmodule WxTest do
      use ExUnit.Case, async: true

      @metar "2023/01/09 15:55\nKRYV 091555Z AUTO 22006KT 7SM CLR M02/M04 A3009 RMK AO2 T10211045\n"

      test "temperature in celsius" do
        result = Wx.parse(@metar)
        assert %{temperature: -2} = result
      end
    end

  # For any other argument (or none), execute Wx.main
  _ ->
    Wx.main(System.argv())
end
