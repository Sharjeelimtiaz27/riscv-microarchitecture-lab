#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <rtl_top.sv> <tb_top.sv> [--waves]"
  exit 1
fi

RTL=$1
TB=$2
WAVES=false
if [ "${3:-}" = "--waves" ]; then
  WAVES=true
fi

WORKDIR=work
ART=artifacts
mkdir -p "$WORKDIR" "$ART"

# detect simulator
if command -v xrun &>/dev/null; then
  SIM="xrun"
elif command -v ncvlog &>/dev/null; then
  SIM="ncvlog"
else
  echo "Cadence tools not found in PATH. Please set PATH to include Cadence binaries."
  exit 2
fi

echo "Using simulator: $SIM"

if [ "$SIM" = "xrun" ]; then
  if [ "$WAVES" = true ]; then
    echo "Running xrun with FSDB wave generation..."
    # -R runs the simulation after elaboration; -access +rwc opens signals for waveform tools
    xrun -sv "$RTL" "$TB" -l "$ART/sim.log" -R -access +rwc -wave "$ART/waves.fsdb"
  else
    echo "Running xrun without FSDB; the TB will produce a waves.vcd file."
    xrun -sv "$RTL" "$TB" -l "$ART/sim.log" -R -access +rwc
  fi
else
  # Basic ncvlog/ncelab/ncsim flow (placeholder, adjust for your cadence)
  ncvlog -sv "$RTL" "$TB" -l "$ART/compile.log"
  ncelab work.top_tb -l "$ART/elab.log"
  ncsim work.top_tb -l "$ART/sim.log"
fi

echo "Simulation finished. Logs: $ART/sim.log"
if [ -f "$ART/waves.fsdb" ]; then
  echo "FSDB wave file: $ART/waves.fsdb"
fi
if [ -f "waves.vcd" ]; then
  echo "VCD wave file: waves.vcd"
fi