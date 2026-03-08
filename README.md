# riscv-microarchitecture-lab

![License](https://img.shields.io/badge/license-MIT-blue)
![RTL](https://img.shields.io/badge/RTL-SystemVerilog-orange)
![Verification](https://img.shields.io/badge/Verification-cocotb%20%7C%20pyuvm-green)
![Formal](https://img.shields.io/badge/Formal-JasperGold-red)
![Simulator](https://img.shields.io/badge/Simulator-Xcelium%20%7C%20Questa-blueviolet)

A public research and teaching lab for designing, verifying, and formally reasoning about RISC-V microarchitectures.

This repository documents the complete CPU development workflow — from RTL design through functional verification to formal proof.

---

## Project Goals

This project demonstrates the complete CPU development stack used in industry.

Main focus areas:

- RTL design in SystemVerilog
- Functional verification using cocotb and pyuvm
- Assertion-based verification using SystemVerilog Assertions (SVA)
- Formal verification using Cadence JasperGold
- Microarchitectural reasoning and security properties
- Weekly research notebooks documenting learning progress

---

## Tools Used

### RTL Simulation

| Tool | Purpose |
|------|---------|
| Cadence Xcelium (xrun) | Primary RTL simulator |
| QuestaSim / ModelSim | Local simulation and debugging |
| GTKWave | Waveform visualization |

Example simulation command:

```bash
xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/*.sv -R -access +rwc
```

### Functional Verification

This project uses Python-based verification in place of traditional SystemVerilog UVM.

| Tool | Purpose |
|------|---------|
| cocotb | Python interface for driving and observing HDL signals |
| pyuvm | Python implementation of the UVM architecture |

Advantages:

- Faster development cycles
- Python ecosystem for testing and debugging
- Easier reference model construction
- Cleaner test automation and scripting

### Formal Verification

| Tool | Purpose |
|------|---------|
| Cadence JasperGold | Property checking and formal proofs |

Formal verification goals include proving:

- Register x0 immutability
- Correct instruction commit ordering
- Memory access safety
- Control-path correctness
- Security invariants

---

## CPU Architecture — Single Cycle

```
          +--------------------+
          |   Program Counter  |
          +---------+----------+
                    |
                    v
          +--------------------+
          | Instruction Memory |
          +---------+----------+
                    |
                    v
          +--------------------+
          |      Decoder       |
          +----+-----------+---+
               |           |
               v           v
       +--------------+   +-------------+
       | Register File|   | Immediate   |
       |              |   | Generator   |
       +------+-------+   +------+------+
              |                  |
              v                  v
                +----------------+
                |      ALU       |
                +--------+-------+
                         |
                         v
                +----------------+
                |   Data Memory  |
                +--------+-------+
                         |
                         v
                   Write Back
```

---

## Verification Architecture

```
                 Python world
 ┌─────────────────────────────────────────┐
 │                                         │
 │  pyuvm                                  │
 │  ├── Test                               │
 │  ├── Environment                        │
 │  │    ├── Agent                         │
 │  │    │    ├── Driver                   │
 │  │    │    ├── Sequencer                │
 │  │    │    └── Monitor                  │
 │  │    └── Scoreboard                    │
 │  │                                      │
 │  └── Sequence                           │
 │                                         │
 └─────────────────────────────────────────┘
                   │
                   │ built on
                   ▼
           cocotb framework
           ├── Clock generator
           ├── Reset control
           ├── Signal read/write
           └── Coroutine scheduling
                   │
                   │ communicates with
                   ▼
         Hardware simulator (Xcelium)
               command: xrun
                   │
                   ▼
        SystemVerilog RTL (RISC-V CPU)
```

### Verification Flow

```
              Sequence
                 │
                 ▼
              Sequencer
                 │
                 ▼
               Driver
                 │
                 ▼
            CPU RTL (DUT)
                 │
                 ▼
               Monitor
                 │
                 ▼
              Scoreboard
                 │
                 ▼
           Pass / Fail Result
```

---

## Formal Verification Flow

```
            RTL + Assertions
                   │
                   ▼
           Formal Harness
                   │
                   ▼
             JasperGold
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
   Property Proven      Counterexample
        │                     │
        ▼                     ▼
  Design Correct      Bug Investigation
```

---

## Repository Structure

```
riscv-microarchitecture-lab/
├── docs/
│   ├── manuals/
│   ├── properties/
│   └── weekly_notebooks/
├── rtl/
│   ├── common/
│   ├── single_cycle/
│   ├── pipeline/
│   └── assertions/
├── tb/
├── tb_pyuvm/
├── simulation_results/
├── tools/
│   └── scripts/
├── README.md
└── LICENSE
```

### Directory Overview

| Directory | Purpose |
|-----------|---------|
| `docs/manuals/` | RISC-V references and documentation |
| `docs/properties/` | Human-readable explanation of assertions |
| `docs/weekly_notebooks/` | Week-by-week learning and research journal |
| `rtl/common/` | Shared RTL modules (ALU, regfile, PC, etc.) |
| `rtl/single_cycle/` | Single-cycle RV32I CPU implementation |
| `rtl/pipeline/` | Future pipelined RV32IMC CPU |
| `rtl/assertions/` | SystemVerilog Assertions |
| `tb/` | Basic simulation testbenches |
| `tb_pyuvm/` | Python-based verification environment |
| `simulation_results/` | Waveforms and test output logs |
| `tools/scripts/` | Simulation helper scripts |

---

## Development Roadmap

**Phase 1 — Single Cycle CPU**
- RV32I instruction support
- Modular RTL architecture
- Smoke tests and waveform validation

**Phase 2 — Functional Verification**
- cocotb testbench
- pyuvm verification environment
- Driver / Monitor / Scoreboard architecture

**Phase 3 — Assertions**
- SystemVerilog Assertions per RTL module
- Simulation-based property checking

**Phase 4 — Formal Verification**
- JasperGold harness
- Microarchitectural invariants
- Corner-case detection and exploration

**Phase 5 — Pipelined CPU**
- 5-stage pipeline
- Hazard detection
- Forwarding logic
- RV32IMC support

---

## Example Smoke Test

Program executed:

```
ADDI x1, x0, 5
ADDI x2, x0, 7
ADD  x3, x1, x2
```

Expected result:

```
x1 = 5
x2 = 7
x3 = 12
```

Simulation output:

```
SMOKE PASS
```

---

## Educational Objective

This repository is designed to help engineers learn:

- CPU microarchitecture design
- Modern verification workflows and methodology
- Python-based UVM methodology
- Formal verification thinking
- Hardware security reasoning

Each development week includes learning notes, architecture diagrams, command flow documentation, and Q&A explanations.

---

## License

MIT License — free to use, modify, and share.

---

## Maintainer

**Sharjeel Imtiaz**  
PhD Student  
Tallinn University of Technology (TalTech)

Contact:
- sharjeel.imtiaz@taltech.ee
- sharjeelimtiazprof@gmail.com