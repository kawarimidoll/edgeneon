#!/bin/sh
# Smoke test for the CLI surface. Builds if no binary is given.
#   ./test.sh                  build main.swift and test it
#   ./test.sh ./result/bin/edgeneon    test an existing binary
#
# The --duration cases matter most: the glow is drawn by AppKit windows, and a
# hook that never exits is worse than one that never lit up. Every case is run
# under an alarm so a hang fails instead of blocking forever. perl is used
# because macOS ships no timeout(1).

bin=$1
if [ -z "$bin" ]; then
  swiftc -O main.swift -o edgeneon || exit 1
  bin=./edgeneon
fi

fails=0

# expect <name> <expected exit> <args...>
expect() {
  name=$1
  want=$2
  shift 2
  perl -e 'alarm shift; exec @ARGV' 20 "$bin" "$@" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name (exit $got, want $want)"
    fails=$((fails + 1))
  fi
}

expect "--help"                 0 --help
expect "--version"              0 --version
expect "rejects bad hex"        1 --colors nope
expect "rejects empty --colors" 1 --colors ""
expect "exits after --duration" 0 --duration 1
expect "custom colors"          0 --colors eb3583,dddccc --duration 1
expect "single color"           0 --colors 22c55e --duration 1
expect "no fade"                0 --duration 1 --fade 0

if [ "$fails" -eq 0 ]; then
  echo "all passed"
else
  echo "$fails failed"
  exit 1
fi
