# Week 02 — Command Reference

RISC-V Microarchitecture Lab | Sharjeel Imtiaz | TalTech | 2026

---

## 1. SSH and Environment Setup

```bash
# Connect to TalTech HPC
ssh sharjeel@<server_address>

cd ~/sharjeelphd/Research/riscv-microarchitecture-lab
git pull

# Load Cadence environment
cad
1.3

# Verify
which xrun
xrun -version
```

---

## 2. Set Python Path for pyuvm

```bash
# Must be set before any xrun + pyuvm command
# tb_pyuvm/ contains driver.py, monitor.py, scoreboard.py, env.py, etc.
export PYTHONPATH="$PWD/tb_pyuvm:$PYTHONPATH"

# Verify pyuvm is importable
python3 -c "import pyuvm; print(pyuvm.__version__)"
```

---

## 3. Install Python Dependencies (first time only)

```bash
# On HPC or local machine
pip install cocotb pyuvm --break-system-packages

# Or using a virtual environment (recommended)
python3 -m venv ~/pyuvm-env
source ~/pyuvm-env/bin/activate
pip install cocotb pyuvm
```

---

## 4. Clean Previous Artifacts

```bash
# Always clean before a fresh run
rm -rf work xcelium.d artifacts/* waves.vcd
mkdir -p artifacts
```

---

## 5. Run pyuvm Smoke Test with Xcelium

```bash
# -python3 enables cocotb integration
# -pythonpath tells xrun where to find tb_pyuvm Python modules
# -access +rwc required for hierarchical signal access in Python
xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/*.sv \
     -R -access +rwc \
     -python3 \
     -pythonpath "$PWD/tb_pyuvm" \
     -l artifacts/xrun_pyuvm.log

# Check result
tail -n 100 artifacts/xrun_pyuvm.log
grep -i "pass\|fail\|error" artifacts/xrun_pyuvm.log
```

---

## 6. VCD Debug — If Waveform Not Generated

```bash
# Check if $dumpfile was reached in simulation
grep -i "dumpfile\|dumpvars\|vcd" artifacts/xrun_pyuvm.log

# If not found: TB is not reaching $dumpvars - check reset timing or early $finish
# Re-run with verbose output
xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/*.sv \
     -R -access +rwc -messages \
     -l artifacts/xrun_debug.log

# Fallback: run on QuestaSim which generates VCD correctly
vlog -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/*.sv
vsim -c work.single_cycle_smoke_tb -do "run -all; quit"
gtkwave waves.vcd
```

---

## 7. Check Coverage (when coverage flags added)

```bash
# Add coverage flags to xrun
xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/*.sv \
     -R -access +rwc \
     -python3 \
     -pythonpath "$PWD/tb_pyuvm" \
     -coverage all \
     -l artifacts/xrun_coverage.log

# Generate coverage report
imc -load cov_work/scope/test -execcmd "report -detail -all" \
    > artifacts/coverage_report.txt
```

---

## 8. Run SVA Assertions in Simulation

```bash
# Compile RTL + checker module together
# basic_props_checker must be instantiated in the testbench
xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv \
     rtl/assertions/basic_props.sv \
     tb/*.sv \
     -R -access +rwc \
     -l artifacts/xrun_sva.log

# Check for assertion failures
grep -i "SVA FAIL\|SVA WARN\|assert" artifacts/xrun_sva.log
```

---

## 9. JasperGold Formal (Template — script not yet written)

```bash
# Run JasperGold in batch mode with a TCL script
jg -batch formal/prove_single_cycle.tcl

# TCL script structure (formal/prove_single_cycle.tcl):
# clear -all
# analyze -sv rtl/common/*.sv rtl/single_cycle/single_cycle_top.sv rtl/assertions/basic_props.sv
# elaborate -top single_cycle_top
# clock clk
# reset !rst_n
# prove -bg -all
# report_results
```

---

## 10. Git Commit

```bash
git add .
git commit -m "week-02: pyuvm environment + SVA basics + commands reference"
git push
```

---

## Notes

- `PYTHONPATH` must be exported before xrun — not just set. Use `export`, not plain assignment.
- Hierarchical access to `dut.rf.regs[i]` requires `-access +rwc`. Without it, reads return X/unknown.
- pyuvm `build_phase` must be called before `connect_phase` — same phase ordering as SystemVerilog UVM.
- Coverage database is written to `cov_work/` by default under Xcelium IMC.
- JasperGold TCL scripts live in `formal/` — one script per property set or module.
