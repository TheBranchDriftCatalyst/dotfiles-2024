#!/usr/bin/env bash
# The mach send contract the bar's IPC patches depend on. See the writeup at the
# top of send_bounded_test.c — in short, a send timeout ALONE does not bound a
# send, and this suite fails if MACH_SEND_INTERRUPT is ever dropped again.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin="$(mktemp -d)/send_bounded_test"
trap 'rm -rf "$(dirname "$bin")"' EXIT

cc -O1 -Wall -Wextra -o "$bin" "$here/send_bounded_test.c"
"$bin"
