# Week 01 — Command Reference

RISC-V Microarchitecture Lab | Sharjeel Imtiaz | TalTech | 2026

---

## 1. SSH and Repo Setup

```bash
# Connect to TalTech HPC
ssh sharjeel@<server_address>

# Navigate to project
cd ~/sharjeelphd/Research/riscv-microarchitecture-lab

# Pull latest changes from GitHub
git pull
```

---

## 2. Load Cadence Environment

```bash
# Load the Cadence EDA module selector
cad

# Select Cadence 2025 version
1.3

# Verify Xcelium is available
which xrun

# Check exact version (should be 24.03-s004)
xrun -version
```

---

## 3. Clean Previous Simulation Artifacts

```bash
# Remove all stale compiled objects, logs, and waveforms
# Always run this before a fresh compile to avoid silent stale-state bugs
rm -rf work xcelium.d artifacts/* waves.vcd

# Create artifacts directory if not present
mkdir -p artifacts
chmod u+rwx artifacts
```

---

## 4. Compile and Elaborate RTL + Testbench

```bash
# Compile all common RTL, single-cycle RTL, and testbench
# -sv enables SystemVerilog 2012
# -l writes the elaboration log to artifacts/
xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/*.sv \
     -l artifacts/xrun_elab.log

# Check for errors or warnings
tail -n 200 artifacts/xrun_elab.log
```

---

## 5. Run Simulation

```bash
# -R runs simulation immediately after elaboration
# -access +rwc opens all signals for waveform dumping and hierarchical access
xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/*.sv \
     -R -access +rwc \
     -l artifacts/xrun_run.log

# Check simulation output and SMOKE PASS/FAIL result
tail -n 100 artifacts/xrun_run.log
```

---

## 6. Inspect Waveform

```bash
# Open VCD waveform in GTKWave
# Add signals: pc, instr, alu_res, wb_data, rf.regs[1..3]
gtkwave waves.vcd
```

---

## 7. Git Workflow

```bash
# Stage all changes
git add .

# Commit with descriptive message (no emojis per repo policy)
git commit -m "week-01: single-cycle RV32I + testbench + waveform"

# Push to GitHub
git push
```

---

## 8. QuestaSim (HPC Backup — Siemens)

```bash
# Compile all sources
vlog -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/*.sv

# Run simulation in command-line mode
vsim -c work.single_cycle_smoke_tb -do "run -all; quit"
```

---

## 9. Assemble RISC-V Program (when needed)

```bash
# Assemble .S file to ELF using RISC-V toolchain
riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32 \
    -nostdlib -Ttext=0 \
    rtl/common/programs/test_rv32i.S \
    -o test_rv32i.elf

# Extract binary
riscv32-unknown-elf-objcopy -O binary test_rv32i.elf test_rv32i.bin

# Convert binary to hex words for $readmemh
python3 tools/scripts/bin2hexwords.py test_rv32i.bin rtl/common/programs/prog1.hex
```

---

## Notes

- Always run step 3 (clean) before step 5 (run) to avoid stale elaboration state.
- The `-access +rwc` flag is required for VCD generation and for pyuvm hierarchical signal access.
- IMEM path is hardcoded in `single_cycle_top.sv` as a parameter — override in testbench with `#(.IMEM_INIT("..."))`.
- If VCD is not generated, check that `$dumpfile` and `$dumpvars` lines appear in the simulation log.
