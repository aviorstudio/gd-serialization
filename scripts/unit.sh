#!/usr/bin/env bash
set -euo pipefail
bash tests/test.sh
bash tests/gate_self_test.sh
