# Setup

Install elixir and erlang

    sudo dnf install -y elixir erlang

Nix users can use ONE of the following:

    nix develop

    # OR, in your .envrc,
    use flake

Run the thing

    elixir wx.exs

Run the tests

    elixir wx.exs test
