Mix.install([
  {:req, "~> 0.3.4"}
])

defmodule Wx do
  def main(args) do
    IO.inspect args
    IO.inspect Req.get!("https://tgftp.nws.noaa.gov/data/observations/metar/stations/KMSN.TXT")
  end

  def parse(_str) do
  end
end

case System.argv() do
  ["test"] -> ExUnit.start()
  _ -> Wx.main(System.argv())
end

defmodule WxTest do
  use ExUnit.Case, async: true

  test "2+2" do
    assert 2+2==4
  end

  test "diff support" do
    assert "a,b,c" == "a,c,d"
  end
end
