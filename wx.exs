#!/bin/elixir

## wx: a METAR parser written in Elixir
# (c) 2023 Al Bowles

Mix.install([
  {:req, "~> 0.3.4"}
])

defmodule Wx do
  # The URL for METAR data
  @data_url "https://tgftp.nws.noaa.gov/data/observations/metar/stations/KMDW.TXT"

  def main(_args) do
    output = parse(metar())
    IO.inspect(output)
  end

  defp c_to_int(str) do
    case str do
      "M" <> rest -> -String.to_integer(rest)
      _ -> String.to_integer(str)
    end
  end

  defp relative_humidity(temp, dewpoint) do
    100 *
      (:math.exp(17.625 * dewpoint / (243.04 + dewpoint)) /
         :math.exp(17.625 * temp / (243.04 + temp)))
  end

  def convert_wind_speed(speed, unit) do
    case unit do
      # TODO case insensitive unit
      "kph" -> round(speed * 1.852)
      "mph" -> round(speed * 1.151)
      _ -> speed
    end
  end

  def parse(metar_string) do
    %{
      "dewpoint" => dp,
      "gusting" => _g,
      "temperature" => t,
      "wind_speed" => ws,
      "wind_direction" => wd
    } =
      Regex.named_captures(
        ~r/(?<gusting>\d{2}G)?(?<wind_direction>\d{3})(?<wind_speed>\d{2})KT\s(?:.*)\s(?<temperature>(M)?(\d{2}))\/(?<dewpoint>(M)?(\d{2}))\s/,
        metar_string
      )

    %{
      temperature_c: c_to_int(t),
      dewpoint: c_to_int(dp),
      relative_humidity: round(relative_humidity(c_to_int(t), c_to_int(dp))),
      wind_bearing: String.to_integer(wd),
      wind_speed_kt: String.to_integer(ws)
    }
  end

  def metar() do
    Req.get!(@data_url).body
  end
end

case System.argv() do
  # if the first arg (after the filename) is "test", run these tests
  ["test"] ->
    ExUnit.start()

    defmodule WxTest do
      use ExUnit.Case, async: true

      @metar "2023/01/09 15:55\nKRYV 091555Z AUTO 22006KT 7SM CLR M02/M04 A3009 RMK AO2 T10211045\n"

      test "Temperature and dewpoint in Celsius" do
        result = Wx.parse(@metar)

        assert %{
                 dewpoint: -4,
                 relative_humidity: 86,
                 temperature_c: -2,
                 wind_speed_kt: 6
               } = result
      end

      test "Wind speed conversion" do
        result = Wx.parse(@metar)
        assert 11 = Wx.convert_wind_speed(result.wind_speed_kt, "kph")
      end
    end

  # Display the raw METAR string
  ["metar"] ->
    IO.inspect(Wx.metar())

  # For any other argument (or none), execute Wx.main
  _ ->
    Wx.main(System.argv())
end
