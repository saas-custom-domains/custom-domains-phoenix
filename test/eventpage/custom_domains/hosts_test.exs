defmodule Eventpage.CustomDomains.HostsTest do
  use ExUnit.Case, async: true

  alias Eventpage.CustomDomains.Hosts

  test "normalize/1 lowercases and drops the port and trailing dot" do
    assert Hosts.normalize(" Events.Acme.COM.:443 ") == "events.acme.com"
    assert Hosts.normalize("events.acme.com:4000") == "events.acme.com"
    assert Hosts.normalize(nil) == ""
  end

  test "valid?/1 accepts hostnames and rejects everything else" do
    assert Hosts.valid?("events.acme.com")
    assert Hosts.valid?("xn--bcher-kva.example")
    refute Hosts.valid?("localhost")
    refute Hosts.valid?("-acme.com")
    refute Hosts.valid?("acme..com")
    refute Hosts.valid?("acme.com/path")
    refute Hosts.valid?("*.acme.com")
    refute Hosts.valid?(String.duplicate("a.", 127) <> "com")
  end

  test "reserved?/1 covers the app hosts and the app domain" do
    assert Hosts.reserved?("localhost")
    assert Hosts.reserved?("eventpage.app")
    assert Hosts.reserved?("admin.eventpage.app")
    refute Hosts.reserved?("noteventpage.app")
    refute Hosts.reserved?("events.acme.com")
  end
end
