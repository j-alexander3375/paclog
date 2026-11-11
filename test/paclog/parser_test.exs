defmodule Paclog.ParserTest do
  use ExUnit.Case, async: true

  alias Paclog.{Entry, Parser}

  @ts "2026-11-08T13:45:21-0500"
  @zone "America/New_York"

  describe "version changes" do
    test "parses an upgrade" do
      line = "[#{@ts}] [ALPM] upgraded linux (6.11.1.arch1-1 -> 6.11.2.arch1-1)"

      assert {:ok,
              %Entry{
                action: :upgraded,
                src: "ALPM",
                pkg: "linux",
                old: "6.11.1.arch1-1",
                new: "6.11.2.arch1-1"
              }} = Parser.parse(line, @zone)
    end

    test "parses a downgrade" do
      line = "[#{@ts}] [ALPM] downgraded mesa (24.2.1-1 -> 24.1.7-1)"

      assert {:ok, %Entry{action: :downgraded, pkg: "mesa", old: "24.2.1-1", new: "24.1.7-1"}} =
               Parser.parse(line, @zone)
    end

    test "handles hyphenated package names and epochs" do
      line = "[#{@ts}] [ALPM] upgraded python-foo (1:1.0-1 -> 1:1.1-1)"

      assert {:ok, %Entry{pkg: "python-foo", old: "1:1.0-1", new: "1:1.1-1"}} =
               Parser.parse(line, @zone)
    end
  end

  describe "single versions" do
    test "parses an install into :new" do
      line = "[#{@ts}] [ALPM] installed foo (1.0-1)"

      assert {:ok, %Entry{action: :installed, pkg: "foo", old: nil, new: "1.0-1"}} =
               Parser.parse(line, @zone)
    end

    test "parses a reinstall into :new" do
      line = "[#{@ts}] [ALPM] reinstalled foo (1.0-1)"

      assert {:ok, %Entry{action: :reinstalled, pkg: "foo", old: nil, new: "1.0-1"}} =
               Parser.parse(line, @zone)
    end

    test "parses a removal into :old" do
      line = "[#{@ts}] [ALPM] removed foo (1.0-1)"

      assert {:ok, %Entry{action: :removed, pkg: "foo", old: "1.0-1", new: nil}} =
               Parser.parse(line, @zone)
    end
  end

  describe "raw line" do
    test "keeps the original line without the trailing newline" do
      line = "[#{@ts}] [ALPM] installed foo (1.0-1)"
      assert {:ok, %Entry{raw: ^line}} = Parser.parse(line <> "\n", @zone)
    end
  end

  describe "skipped lines" do
    test "skips transaction markers" do
      assert :skip = Parser.parse("[#{@ts}] [ALPM] transaction started", @zone)
      assert :skip = Parser.parse("[#{@ts}] [ALPM] transaction completed", @zone)
    end

    test "skips pacman commands and scriptlet output" do
      assert :skip = Parser.parse("[#{@ts}] [PACMAN] Running 'pacman -Syu'", @zone)
      assert :skip = Parser.parse("[#{@ts}] [ALPM-SCRIPTLET] ==> Building initcpio...", @zone)
    end

    test "skips lines that don't match the outer format" do
      assert :skip = Parser.parse("", @zone)
      assert :skip = Parser.parse("not a log line", @zone)
    end

    test "skips a version change with no arrow" do
      assert :skip = Parser.parse("[#{@ts}] [ALPM] upgraded foo (1.0-1)", @zone)
    end

    test "skips an action with no version" do
      assert :skip = Parser.parse("[#{@ts}] [ALPM] installed foo", @zone)
    end
  end

  describe "fixture" do
    test "parses the real log without crashing and finds package entries" do
      results =
        "test/fixtures/pacman.log"
        |> File.stream!()
        |> Enum.map(&Parser.parse(&1, @zone))

      assert Enum.all?(results, &(match?({:ok, %Entry{}}, &1) or &1 == :skip))
      assert Enum.any?(results, &match?({:ok, _}, &1))
    end
  end

  # These fail until parse_time/2 is implemented.
  # Run everything else with: mix test --exclude timestamp
  describe "timestamps" do
    @describetag :timestamp

    test "converts the current ISO 8601 format to UTC" do
      line = "[2026-11-08T13:45:21-0500] [ALPM] installed foo (1.0-1)"
      assert {:ok, %Entry{time: time}} = Parser.parse(line, @zone)
      assert time == ~U[2026-11-08 18:45:21Z]
    end

    test "interprets the old format in the given zone and converts to UTC" do
      # noon EST (UTC-5) is 17:00 UTC
      line = "[2019-01-01 12:00] [ALPM] installed foo (1.0-1)"
      assert {:ok, %Entry{time: time}} = Parser.parse(line, @zone)
      assert time == ~U[2019-01-01 17:00:00Z]
    end

    test "the zone only affects old-format lines" do
      line = "[2026-11-08T13:45:21-0500] [ALPM] installed foo (1.0-1)"
      assert {:ok, %Entry{time: t1}} = Parser.parse(line, @zone)
      assert {:ok, %Entry{time: t2}} = Parser.parse(line, "Etc/UTC")
      assert t1 == t2
    end

    test "returns :skip for an unparseable timestamp" do
      assert :skip = Parser.parse("[not-a-time] [ALPM] installed foo (1.0-1)", @zone)
    end

    test "picks the earlier moment for ambiguous times" do
      line = "[2026-11-01 01:30] [ALPM] installed foo (1.0-1)"
      assert {:ok, %Entry{time: ~U[2026-11-01 05:30:00Z]}} = Parser.parse(line, @zone)
    end

    test "picks the moment after the jump for gap times" do
      line = "[2026-03-08 02:30] [ALPM] installed foo (1.0-1)"
      assert {:ok, %Entry{time: ~U[2026-03-08 07:00:00Z]}} = Parser.parse(line, @zone)
    end
  end
end
