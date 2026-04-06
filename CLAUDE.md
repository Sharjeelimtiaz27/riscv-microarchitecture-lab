# CLAUDE.md — RISC-V Microarchitecture Lab
## Master Context for Claude Code Sessions

**Maintainer:** Sharjeel Imtiaz | PhD Student | Tallinn University of Technology (TalTech)
**Contact:** sharjeel.imtiaz@taltech.ee | sharjeelimtiazprof@gmail.com
**Repository:** riscv-microarchitecture-lab

---

## Project Vision

Design a complete, production-quality 64-bit RISC-V processor from architectural specification to physical chip implementation.

The processor will be:
- RV64IM to start, with a roadmap to RV64IMACE
- Out-of-order execution, 5-stage pipeline
- All privilege levels (M/S/U) per the RISC-V specification
- Capable of booting a small Linux kernel
- Open for community extension: UART, AI accelerators, crypto cores, etc.
- Available in two variants: standard and logic-locked (secure)

This is also a structured learning project. The goal is for Sharjeel to reach the point where he can independently start any verification task (pyuvm/cocotb testbench, SVA properties, RTL module) without AI assistance, then use Claude to go faster and deeper.

---

## Weekly Documentation Workflow

At the end of every work week, Claude Code generates two files for that week:

**Three files are generated per week:**

**1. `weekNN.md`** — `docs/weekly_notebooks/weekNN.md`
- Theory, concepts, architecture explanations, lessons learned, interview Q&A
- No command dumps — just learning content
- Public on GitHub, useful for other engineers and students

**2. `weekNN_commands.md`** — `docs/weekly_notebooks/weekNN_commands.md`
- Commands only, organized by task
- Every command has a one-line comment explaining what it does and why
- Meant to be a fast copy-paste reference during future sessions
- No theory, no prose — purely operational

**3. `weekNN_research_notebook.docx`** — `docs/weekly_notebooks/weekNN_research_notebook.docx`
- Everything woven together as one flowing readable document
- Commands appear inline where they are needed, not in a separate section
- Rich formatting: color tables, dark code blocks, Q&A boxes, page numbers
- Best for studying and interview prep

**How to trigger this in Claude Code:**

At the end of a session, say:
> "Generate the Week NN docs"

Claude Code generates all three files and places them in `docs/weekly_notebooks/`.

**What goes in each file:**

| Content | weekNN.md | weekNN_commands.md | .docx |
|---------|-----------|-------------------|-------|
| Objectives | Yes | No | Yes |
| Theory and explanations | Yes | No | Yes |
| Commands with context | No | Yes | Yes, inline |
| Progress tracker | Yes | No | Yes |
| Lessons learned | Yes | No | Yes |
| Interview Q&A | Yes | No | Yes |
| Next week plan | Yes | No | Yes |

**Naming convention:**
```
docs/weekly_notebooks/week01.md
docs/weekly_notebooks/week01_commands.md
docs/weekly_notebooks/week01_research_notebook.docx
```

---

## Phase Roadmap

```
Phase 0  [DONE]     Single-cycle RV32I  -  RTL complete, smoke test passing
Phase 1  [ACTIVE]   Single-cycle verification  -  pyuvm + cocotb + SVA + JasperGold + Genus + Innovus
Phase 2  [NEXT]     RV64IM 5-stage pipeline  -  fetch/decode/execute/mem/writeback
Phase 3             Hazard unit  -  data hazards, forwarding, stall control
Phase 4             Branch prediction  -  BTB, static predictor first
Phase 5             Out-of-order  -  ROB, reservation stations, register renaming
Phase 6             Privilege levels  -  M/S/U, CSR file, trap/interrupt handling
Phase 7             Linux capable  -  MMU, SV39 virtual memory, timer
Phase 8             Security variant  -  logic locking, secure configuration mode
Phase 9             Peripherals  -  UART baseline, open peripheral interface
Phase 10            Physical  -  Genus synthesis, Innovus P&R, timing closure
```

---

## Current State (as of Week 02)

**Completed:**
- Single-cycle RV32I RTL: pc, regfile, alu, alu_ctrl, immgen, inst_memory, data_memory, single_cycle_top
- Smoke testbench: `single_cycle_smoke_tb.sv`
- Smoke test passed: x1=5, x2=7, x3=12 — SMOKE PASS
- pyuvm skeleton: driver, monitor, scoreboard, sequencer, env, sequence, test
- SVA basics file: `basic_props.sv` — x0_immutable, opcode_nonzero_after_fetch
- VCD generated and verified in QuestaSim

**Known open issue:**
- Xcelium smoke testbench did NOT generate VCD. QuestaSim worked. Must investigate next session.
  - Likely cause: `$dumpfile`/`$dumpvars` in TB not being reached, or xrun flags missing `-access +rwc`
  - First step: check `artifacts/xrun_run.log` for TB output and VCD-related messages

**Immediate next tasks (in order):**
1. Fix VCD generation under Xcelium — verify `$dumpfile`/`$dumpvars` are hit
2. Run the pyuvm smoke test end-to-end with Xcelium, confirm PASS + coverage report
3. Add functional coverage groups to monitor (register write events, opcode coverage)
4. Extend SVA properties: pc_aligned, writeback_correctness, mem_bounds
5. Bind `basic_props_checker` into the top-level for simulation-time assertion checking
6. Set up JasperGold TCL script to prove x0_immutable formally
7. Run Genus synthesis on single-cycle RTL — generate area/timing report
8. Run Innovus on synthesized netlist — generate basic P&R result

---

## Target Processor Specification (Phase 2+)

| Attribute | Value |
|-----------|-------|
| ISA | RV64IM (baseline), RV64IMACE (target) |
| Pipeline | 5-stage: IF / ID / EX / MEM / WB |
| Execution | Out-of-order (ROB-based) |
| Privilege | Machine / Supervisor / User (per RISC-V spec vol II) |
| Virtual Memory | SV39 (39-bit virtual, for Linux) |
| CSR | Full M-mode + S-mode CSR file |
| Reset Vector | 0x80000000 (standard for Linux RISC-V) |
| Endianness | Little-endian |
| Security variant | Logic-locked configuration mode |

---

## Tools and Environment

| Category | Tool | Notes |
|----------|------|-------|
| RTL Simulator | Cadence Xcelium (xrun) | Primary, TalTech HPC |
| RTL Simulator | QuestaSim / ModelSim | Backup, local Windows |
| Functional Verification | cocotb + pyuvm | Python-based UVM |
| Formal Verification | Cadence JasperGold | University license |
| Logic Synthesis | Cadence Genus | University license |
| Place and Route | Cadence Innovus | University license |
| Waveforms | GTKWave | VCD files |
| Version Control | Git / GitHub | Main branch: main |
| HPC | TalTech HPC servers | ssh sharjeel@<server> |

**Cadence environment setup on HPC:**
```bash
cad
1.3                  # loads Cadence 2025 EDA
which xrun           # should return /eda/cadence/.../xrun
xrun -version        # should show 24.03-s004
```

---

## Repository Structure

```
riscv-microarchitecture-lab/
├── CLAUDE.md                      # this file
├── README.md
├── LICENSE
├── rtl/
│   ├── common/                    # shared RTL: alu, regfile, pc, immgen, memories
│   │   └── programs/              # hex files: prog1.hex, test_rv32i.S
│   ├── single_cycle/              # single_cycle_top.sv
│   ├── pipeline/                  # (Phase 2+) 5-stage RV64IM
│   └── assertions/                # SVA files: basic_props.sv
├── tb/                            # basic SV testbenches: single_cycle_smoke_tb.sv
├── tb_pyuvm/
│   └── pyuvm_env/                 # driver.py, monitor.py, scoreboard.py, env.py, sequence.py, sequencer.py, test_single_cycle.py
├── tools/
│   └── scripts/                   # run_cadence.sh, run_pyuvm_xrun.sh, bin2hexwords.py
├── docs/
│   ├── weekly_notebooks/          # week1.md, week2.md, ...
│   └── properties/                # human-readable SVA documentation
├── simulation_results/            # waves.vcd, logs
├── formal/                        # JasperGold TCL scripts and results
├── syn/                           # Genus synthesis scripts and reports
├── pnr/                           # Innovus P&R scripts and results
└── .claude/
    └── napkin.md                  # Claude Code session runbook
```

---

## Coding Standards and Conventions

### General Rules (always follow)
- No emojis anywhere in code, comments, or documentation
- File headers use the standard project banner (see any existing .sv file)
- All RTL is SystemVerilog 2012 (`-sv` flag, `always_comb`, `always_ff`, `logic` type)
- Use `logic` not `wire` or `reg` in SystemVerilog
- Module names match file names exactly
- Python files use snake_case; SV files use snake_case

### SystemVerilog RTL Conventions
- Use `always_comb` for combinational logic (never `always @(*)`)
- Use `always_ff @(posedge clk or negedge rst_n)` for sequential
- Active-low reset signal is named `rst_n`
- Default case in all `unique case` statements
- No latches — every `always_comb` must have full assignment coverage
- `ibex_csr` quirk: use logical operators (`&&`, `||`) not bitwise (`&`, `|`) in conditions

### Assertion Style
- All assertions in separate checker modules, not inline in RTL
- Module naming: `<block>_props_checker`
- Always include `disable iff (!rst_n)` in concurrent assertions
- Comment each property with plain-English intent above it

### Python / pyuvm Conventions
- Class names: PascalCase (e.g., `SingleCycleDriver`)
- Component constructors always accept `(name, parent)` or `(name, parent, dut)`
- No bare `print()` for pass/fail — use `cocotb.log.info()` or `cocotb.log.error()`
- All cocotb tests use `@cocotb.test()` decorator
- Async functions use `await` properly — never mix sync/async without care

### Commit Messages
- Format: `<scope>: <short description>`
- Examples: `rtl: add branch logic to single_cycle_top`, `uvm: extend scoreboard for coverage`, `formal: add pc_aligned property`
- No emojis in commit messages

---

## Learning Goals (Sharjeel's Mid-Level Targets)

The goal is to be able to independently start the following without AI help:

**SystemVerilog RTL:**
- Write a new pipeline stage module from scratch
- Implement a hazard detection unit
- Implement a forwarding unit
- Write a CSR file with trap/interrupt logic

**pyuvm / cocotb:**
- Create a new UVM component (driver/monitor/scoreboard) from a blank file
- Write a randomized sequence that exercises a set of instructions
- Add functional coverage groups to a monitor
- Connect components through TLM ports

**SVA Properties:**
- Write immediate and concurrent assertions
- Use `$past`, `$stable`, implication (`|->`, `|=>`)
- Write a safety property vs a liveness property
- Understand what bounded model checking means for your property

**JasperGold:**
- Write a basic TCL prove script
- Interpret a counterexample trace
- Understand assume/assert/cover distinction

---

## Key File Reference

| File | Purpose |
|------|---------|
| `rtl/common/alu.sv` | ALU: ADD/SUB/AND/OR/XOR/SLT/SLL/SRL/SRA |
| `rtl/common/alu_ctrl.sv` | ALU opcode decoder for R-type and I-type |
| `rtl/common/regfile.sv` | 32-register file, x0 hardwired to 0 |
| `rtl/common/pc.sv` | Program counter register |
| `rtl/common/immgen.sv` | Immediate generator for all RV32I formats |
| `rtl/common/inst_memory.sv` | Instruction memory, $readmemh init |
| `rtl/common/data_memory.sv` | Data memory, 256 words |
| `rtl/single_cycle/single_cycle_top.sv` | Top-level integration |
| `tb/single_cycle_smoke_tb.sv` | SV smoke testbench |
| `rtl/assertions/basic_props.sv` | SVA checker module |
| `tb_pyuvm/pyuvm_env/test_single_cycle.py` | cocotb top-level test |
| `rtl/common/programs/prog1.hex` | Smoke test program hex |
| `tools/scripts/run_cadence.sh` | Generic Xcelium run script |
| `tools/scripts/run_pyuvm_xrun.sh` | pyuvm + Xcelium run script |

---

## Common Commands

### Xcelium Simulation
```bash
# Load Cadence on HPC
cad && 1.3

# Clean + compile + run
rm -rf work xcelium.d artifacts/* waves.vcd
mkdir -p artifacts
xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/*.sv \
     -R -access +rwc \
     -l artifacts/xrun_run.log

# Check result
tail -n 50 artifacts/xrun_run.log
```

### pyuvm with Xcelium
```bash
export PYTHONPATH="$PWD/tb_pyuvm:$PYTHONPATH"
xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/single_cycle_smoke_tb.sv \
     -R -access +rwc \
     -python3 \
     -pythonpath "$PWD/tb_pyuvm" \
     -l artifacts/xrun_pyuvm.log
```

### JasperGold (when script exists)
```bash
jg -batch formal/prove_single_cycle.tcl
```

### Genus Synthesis (when script exists)
```bash
genus -f syn/single_cycle_syn.tcl
```

### QuestaSim (HPC, Siemens)
```bash
vlog -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/*.sv
vsim -c work.single_cycle_smoke_tb -do "run -all; quit"
```

---

## JasperGold TCL Template (reference)
```tcl
# formal/prove_single_cycle.tcl
clear -all
analyze -sv rtl/common/*.sv rtl/single_cycle/single_cycle_top.sv rtl/assertions/basic_props.sv
elaborate -top single_cycle_top
clock clk
reset !rst_n
prove -bg -all
report_results
```

---

## Genus Synthesis Template (reference)
```tcl
# syn/single_cycle_syn.tcl
read_hdl -sv rtl/common/*.sv rtl/single_cycle/single_cycle_top.sv
elaborate single_cycle_top
read_sdc constraints/single_cycle.sdc
syn_generic
syn_map
syn_opt
write_hdl -mapped > syn/results/single_cycle_mapped.v
report_area
report_timing
```

---

## Open Issues Log

| Issue | Status | Notes |
|-------|--------|-------|
| Xcelium no VCD output | Open | TB $dumpfile not reached or flags wrong; QuestaSim works fine |
| pyuvm sequence.body() is empty | Known | Smoke test uses pre-loaded IMEM; body() will be extended for randomized tests |
| alu_ctrl missing SLT/SLL/SRL/SRA for R-type | Known | Only ADD/SUB/AND/OR/XOR currently mapped |
| single_cycle_top missing branch/jump logic | Known | Intentional for smoke test; needed for full RV32I coverage |
| IMEM path hardcoded in single_cycle_top | Known | Parameter overridden in TB; will be made relative for HPC portability |

---

## Research Context

- **SecMetric paper**: targeting IEEE TCAD resubmission. Addressing reviewer concerns: threat model scope, algorithmic novelty depth. FORTRESS covert-channel detection for NaxRiscv, positioned vs AutoCC (Princeton MICRO 2023).
- **RV-TroGen**: automated hardware trojan generation framework targeting ibex_csr. Snippet-based insertion, validated via QuestaSim on TalTech HPC.
- **Logic locking variant**: planned for the final processor — configurable normal/secure mode.
- **Guest lecture**: IAS0630 at TalTech — Verilog/digital design. Teaching materials maintained in docs/.

---

*Keep this file updated as the project evolves. It is the single source of truth for Claude Code sessions.*
