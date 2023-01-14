#!/bin/elixir

## wx: a METAR parser written in Elixir
# (c) 2023 Al Bowles

Mix.install([
  {:req, "~> 0.3.4"}
])

defmodule Wx do
  # The URL for METAR data
  # TODO accept station as argument
  @data_url "https://tgftp.nws.noaa.gov/data/observations/metar/stations/KRYV.TXT"

  def main(_args) do
    output = parse(metar())
    IO.inspect(output)
  end

  defp c_to_int("M" <> str), do: -c_to_int(str)
  defp c_to_int(str), do: String.to_integer(str)
  defp kt_to_int(""), do: nil
  defp kt_to_int(str), do: String.to_integer(str)

  defp relative_humidity(temp, dewpoint) do
    100 *
      (:math.exp(17.625 * dewpoint / (243.04 + dewpoint)) /
         :math.exp(17.625 * temp / (243.04 + temp)))
  end

  def convert_wind_speed(speed, unit) do
    case String.downcase(unit) do
      "kph" -> round(speed * 1.852)
      "mph" -> round(speed * 1.151)
      _ -> speed
    end
  end

  def convert_temperature(temperature, unit) do
    case unit do
      "f" -> round(temperature * 9 / 5 + 32)
      "k" -> temperature + 270
      _ -> temperature
    end
  end

  def calculate_wind_chill(temperature_c, wind_speed_kph) do
    cond do
      temperature_c > 10 ->
        false

      wind_speed_kph < 4.8 ->
        false

      true ->
        13.12 + 0.6215 * temperature_c - 11.37 * :math.pow(wind_speed_kph, 0.16) +
          0.3965 * temperature_c * :math.pow(wind_speed_kph, 0.16)
    end
  end

  def calculate_heat_index(temperature_c, relative_humidity) do
    cond do
      temperature_c < 27 ->
        false

      true ->
        c1 = -8.78469475556
        c2 = 1.61139411
        c3 = 2.33854883889
        c4 = -0.14611605
        c5 = -0.012308094
        c6 = -0.0164248277778
        c7 = 0.002211732
        c8 = 0.00072546
        c9 = -0.000003582

        c1 + c2 * temperature_c + c3 * relative_humidity + c4 * temperature_c * relative_humidity +
          c5 * :math.pow(temperature_c, 2) + c6 * :math.pow(relative_humidity, 2) +
          c7 * :math.pow(temperature_c, 2) * relative_humidity +
          c8 * temperature_c * :math.pow(relative_humidity, 2) +
          c9 * (:math.pow(temperature_c, 2) * :math.pow(relative_humidity, 2))
    end
  end

  defp translate_condition(c) do
    case c do
      c when c in ["CLR", "SKC"] -> "clear"
      "FEW" -> "partly cloudy"
      "SCT" -> "cloudy"
      "BKN" -> "mostly cloudy"
      "OVC" -> "overcast"
      "VV" -> "vertical visibility"
      "" -> false
    end
  end

  defp translate_quality(quality) do
    case quality do
      "+" -> "heavy"
      "-" -> "light"
      "VC" -> "vicinity"
      "" -> nil
    end
  end

  defp translate_other(other) do
    case other do
      "SQ" -> "squall"
      "SS" -> "sandstorm"
      "FC" -> "tornado"
      "DS" -> "dust storm"
      "PO" -> "sand whirls"
      "" -> nil
    end
  end

  defp translate_description(description) do
    case description do
      "MI" -> "shallow"
      "BL" -> "blowing"
      "BC" -> "patchy"
      "SH" -> "showers"
      "PR" -> "partial"
      "DR" -> "drifting"
      "TS" -> "thunderstorms"
      "FZ" -> "freezing"
      "" -> nil
    end
  end

  defp translate_precipitation(precipitation) do
    case precipitation do
      "DZ" -> "drizzle"
      "IC" -> "ice crystals"
      "UP" -> "unknown"
      "RA" -> "rado"
      "PL" -> "ice pellets"
      "SN" -> "snow"
      "GR" -> "hail"
      "SG" -> "snow grados"
      "GS" -> "small hail"
      "" -> nil
    end
  end

  defp translate_obscurity(obscurity) do
    case obscurity do
      "BR" -> "mist"
      "SA" -> "sand"
      "FU" -> "smoke"
      "FG" -> "fog"
      "HZ" -> "haze"
      "VA" -> "volcanic ash"
      "PY" -> "spray"
      "DU" -> "dust"
      "" -> nil
    end
  end

  defp translate_phenomena(quality, description, precipitation, obscurity, other) do
    phenomena =
      Enum.reject(
        [
          translate_quality(quality),
          translate_description(description),
          translate_precipitation(precipitation),
          translate_obscurity(obscurity),
          translate_other(other)
        ],
        &is_nil/1
      )

    if length(phenomena) > 0 do
      Enum.join(phenomena, " ")
    else
      nil
    end
  end

  def parse(metar_string) do
    %{
      "condition" => c,
      "dewpoint" => dp,
      "gusting" => g,
      "quality" => qual,
      "description" => desc,
      "precipitation" => prec,
      "obscurity" => obs,
      "other" => oth,
      "temperature" => t,
      "visibility" => v,
      "wind_speed" => ws,
      "wind_direction" => wd
    } =
      Regex.named_captures(
        ~r/(?<wind_direction>\d{3})(?<wind_speed>\d{2})(?:G(?<gusting>\d{2}))?KT\s(?<visibility>\d+)SM(?:\s(?<quality>\+|-|VC)?(?<description>MI|BL|BC|SH|PR|DR|TS|FZ)?(?<precipitation>DZ|IC|UP|RA|PL|SN|GR|SG|GS)?(?<obscurity>BR|SA|FU|HZ|VA|PY|DU|FG)?(?<other>SQ|FC|SS|DS|PO)?)?\s(?<condition>CLR|SKC|FEW|SCT|BKN|OVC|VV)(?:\d{3})?(?:.*)?\s(?<temperature>M?(\d{2}))\/(?<dewpoint>M?(\d{2}))/,
        metar_string
      )

    %{
      condition: translate_condition(c),
      dewpoint_c: c_to_int(dp),
      phenomena: translate_phenomena(qual, desc, prec, obs, oth),
      relative_humidity: round(relative_humidity(c_to_int(t), c_to_int(dp))),
      temperature_c: c_to_int(t),
      visibility_mi: String.to_integer(v),
      wind_bearing: String.to_integer(wd),
      wind_gusting_kt: kt_to_int(g),
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

      test "METAR parsing" do
        cases = [
          %{
            input:
              "2023/01/13 15:53\nKMSN 131553Z 36010G18KT 10SM OVC029 M03/M08 A3030 RMK AO2 SLP273 T10281083\n",
            output: %{
              condition: "overcast",
              dewpoint_c: -8,
              phenomena: nil,
              relative_humidity: 68,
              temperature_c: -3,
              visibility_mi: 10,
              wind_bearing: 360,
              wind_gusting_kt: 18,
              wind_speed_kt: 10
            }
          },
          %{
            input:
              "2023/01/09 15:55\nKRYV 091555Z AUTO 22006KT 7SM CLR M02/M04 A3009 RMK AO2 T10211045\n",
            output: %{
              condition: "clear",
              dewpoint_c: -4,
              phenomena: nil,
              relative_humidity: 86,
              temperature_c: -2,
              visibility_mi: 7,
              wind_bearing: 220,
              wind_gusting_kt: nil,
              wind_speed_kt: 6
            }
          },
          %{
            input:
              "2023/01/12 01:26\nKMDW 120126Z 19003KT 8SM BKN021 OVC033 09/06 A2980 RMK AO2 T00890056\n",
            output: %{
              condition: "mostly cloudy",
              dewpoint_c: 6,
              phenomena: nil,
              relative_humidity: 81,
              temperature_c: 9,
              visibility_mi: 8,
              wind_bearing: 190,
              wind_gusting_kt: nil,
              wind_speed_kt: 3
            }
          },
          %{
            input:
              "2023/01/12 00:56\nKHNB 120056Z AUTO 00000KT 4SM BR BKN036 12/12 A2984 RMK AO2 SLP105 T01170117\n",
            output: %{
              condition: "mostly cloudy",
              dewpoint_c: 12,
              phenomena: "mist",
              relative_humidity: 100,
              temperature_c: 12,
              visibility_mi: 4,
              wind_bearing: 0,
              wind_gusting_kt: nil,
              wind_speed_kt: 0
            }
          },
          %{
            input:
              "2023/01/10 20:53\nKDFW 102053Z 21018KT 10SM BKN250 28/07 A2983 RMK AO2 PK WND 22026/2011 SLP095 T02830067 56036\n",
            output: %{
              condition: "mostly cloudy",
              dewpoint_c: 7,
              phenomena: nil,
              relative_humidity: 27,
              temperature_c: 28,
              visibility_mi: 10,
              wind_bearing: 210,
              wind_gusting_kt: nil,
              wind_speed_kt: 8
            }
          }
        ]

        for {input, output} <- cases, do: assert(output = Wx.parse(input))
      end

      #      test "Wind speed conversion" do
      #        assert 11 = Wx.convert_wind_speed(@cases[0].output.wind_speed_kt, "kph")
      #        assert 7 = Wx.convert_wind_speed(@cases[0].output.wind_speed_kt, "mph")
      #      end

      #      test "Wind speed conversion with gusts" do
      #        assert 12 = Wx.convert_wind_speed(Wx.parse(@metar_msn).wind_speed_kt, "mph")
      #        assert 21 = Wx.convert_wind_speed(Wx.parse(@metar_msn).wind_gusting_kt, "mph")
      #      end
      #
      #      test "Temperature conversion" do
      #        assert 28 = Wx.convert_temperature(Wx.parse(@metar_ryv).temperature_c, "f")
      #        assert 268 = Wx.convert_temperature(Wx.parse(@metar_ryv).temperature_c, "k")
      #      end
      #
      #      test "Calculate wind chill" do
      #        assert -6 =
      #                 round(
      #                   Wx.calculate_wind_chill(
      #                     Wx.parse(@metar_ryv).temperature_c,
      #                     Wx.convert_wind_speed(Wx.parse(@metar_ryv).wind_speed_kt, "kph")
      #                   )
      #                 )
      #      end
      #
      #      test "Calculate heat index" do
      #        assert 27 =
      #                 round(
      #                   Wx.calculate_heat_index(
      #                     Wx.parse(@metar_dfw).temperature_c,
      #                     Wx.parse(@metar_dfw).relative_humidity
      #                   )
      #                 )
      #      end
    end

  # Display a summary of current conditions
  ["summary"] ->
    result = Wx.parse(Wx.metar())
    IO.puts("#{Wx.convert_temperature(result.temperature_c, "f")}°F #{result.condition}")

  # Display the raw METAR string
  ["metar"] ->
    IO.inspect(Wx.metar())

  # For any other argument (or none), execute Wx.main
  _ ->
    Wx.main(System.argv())
end
