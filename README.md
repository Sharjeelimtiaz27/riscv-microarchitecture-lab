# riscv-microarchitecture-lab

![License](https://img.shields.io/badge/license-MIT-blue)
![RTL](https://img.shields.io/badge/RTL-SystemVerilog-orange)
![Verification](https://img.shields.io/badge/Verification-cocotb%20%7C%20pyuvm-green)
![Formal](https://img.shields.io/badge/Formal-JasperGold-red)
![Simulator](https://img.shields.io/badge/Simulator-Xcelium%20%7C%20Questa-blueviolet)
![Synthesis](https://img.shields.io/badge/Synthesis-Cadence%20Genus-yellow)
![PnR](https://img.shields.io/badge/Place%20%26%20Route-Cadence%20Innovus-9cf)

A public research and teaching lab for designing, verifying, and formally reasoning about RISC-V microarchitectures — from specification all the way to physical chip implementation.

This repository documents the complete development workflow for a 64-bit RISC-V processor (RV64IM): RTL design, functional verification, assertion-based verification, formal proof, logic synthesis, and place-and-route.

## Project Goals

This project demonstrates the complete CPU development stack used in industry, from first RTL to a fabrication-ready chip. The target is a production-quality 64-bit RISC-V processor (RV64IM baseline, roadmap to RV64IMACE) with out-of-order execution, all privilege levels, and Linux boot capability. A logic-locked security variant is planned alongside the standard implementation.

The full stack covered in this project:

- RTL design in SystemVerilog
- Functional verification using cocotb and pyuvm
- Assertion-based verification using SystemVerilog Assertions (SVA)
- Formal verification using Cadence JasperGold
- Security verification: microarchitectural invariants and logic locking
- Logic synthesis using Cadence Genus
- Place-and-route using Cadence Innovus
- Physical chip implementation as the final deliverable

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

This project uses Python-based verification in place of traditional SystemVerilog UVM. cocotb provides the Python interface into the simulator, and pyuvm implements the standard UVM architecture on top of it. The result is faster testbench development, easier reference model construction, and full access to the Python ecosystem for scripting and debugging.

| Tool | Purpose |
|------|---------|
| cocotb | Python interface for driving and observing HDL signals |
| pyuvm | Python implementation of the UVM architecture |

### Formal Verification

| Tool | Purpose |
|------|---------|
| Cadence JasperGold | Property checking and formal proofs |

Formal verification goals include proving register x0 immutability, correct instruction commit ordering, memory access safety, control-path correctness, and security invariants including information flow and privilege isolation.

### Logic Synthesis and Physical Implementation

| Tool | Purpose |
|------|---------|
| Cadence Genus | Logic synthesis: RTL to gate-level netlist, area and timing reports |
| Cadence Innovus | Place-and-route: floorplanning, routing, timing closure, GDSII output |

The final goal of this project is a fully placed-and-routed chip. Every phase of design and verification feeds toward a fabrication-ready implementation.

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
├── formal/
├── syn/
├── pnr/
├── simulation_results/
├── tools/
│   └── scripts/
├── README.md
└── LICENSE
```

| Directory | Purpose |
|-----------|---------|
| `docs/manuals/` | RISC-V references and documentation |
| `docs/properties/` | Human-readable explanation of assertions |
| `docs/weekly_notebooks/` | Week-by-week learning and research journal |
| `rtl/common/` | Shared RTL modules (ALU, regfile, PC, etc.) |
| `rtl/single_cycle/` | Single-cycle RV32I CPU implementation |
| `rtl/pipeline/` | Pipelined RV64IM CPU (Phase 2+) |
| `rtl/assertions/` | SystemVerilog Assertions |
| `tb/` | Basic simulation testbenches |
| `tb_pyuvm/` | Python-based pyuvm verification environment |
| `formal/` | JasperGold TCL scripts and formal results |
| `syn/` | Genus synthesis scripts and area/timing reports |
| `pnr/` | Innovus place-and-route scripts and GDSII output |
| `simulation_results/` | Waveforms and test output logs |
| `tools/scripts/` | Simulation and flow helper scripts |

## Development Roadmap

**Phase 0 — Single-Cycle RV32I [DONE]**
Modular RTL: ALU, register file, PC, immediate generator, memories, and top-level integration. Smoke test passing with x1=5, x2=7, x3=12.

**Phase 1 — Verification of Single-Cycle CPU [ACTIVE]**
cocotb and pyuvm functional verification environment with Driver, Monitor, and Scoreboard. SystemVerilog Assertions per module. Formal proof of microarchitectural invariants with JasperGold, including security properties. Logic synthesis with Genus and place-and-route with Innovus to produce a first physical result for the single-cycle design.

**Phase 2 — RV64IM 5-Stage Pipelined CPU**
64-bit datapath with a 5-stage pipeline (IF, ID, EX, MEM, WB), hazard detection, forwarding unit, and out-of-order execution with a reorder buffer and reservation stations.

**Phase 3 — Privilege Levels and OS Support**
Machine, Supervisor, and User privilege levels per the RISC-V privileged specification. Full CSR file with trap and interrupt handling. SV39 virtual memory and MMU. The processor will be capable of booting a small Linux kernel, with an optional FPGA port for live testing.

**Phase 4 — Security Variant**
Logic locking with a configurable normal and secure mode. Formal verification of security properties on the locked variant.

**Phase 5 — Open Peripheral Interface**
UART as the baseline peripheral. An open interface for community-contributed extensions including AI accelerators, cryptographic cores, and custom instruction sets.

**Phase 6 — Physical Chip (Final Goal)**
Full Genus synthesis of the complete processor, Innovus place-and-route with timing closure, and fabrication-ready GDSII output.

## Example Smoke Test

Program executed:

```
ADDI x1, x0, 5
ADDI x2, x0, 7
ADD  x3, x1, x2
```

Expected result: x1=5, x2=7, x3=12. Simulation output: SMOKE PASS.

## Educational Objective

This repository is designed to help engineers learn the complete CPU development stack: microarchitecture design from specification, functional verification with Python-based UVM, formal verification and hardware security reasoning, logic synthesis, and physical implementation. Each development week includes learning notes, architecture diagrams, command references, and Q&A explanations, all written to help build the mental model rather than just deliver code.

## Open for Contributions

This processor is designed to be extended. Once the core is stable, the peripheral interface will be open for community contributions. If you want to add a peripheral, an AI accelerator, a cryptographic core, or any other extension, open an issue or pull request.

## License

MIT License — free to use, modify, and share.

## Maintainer

**Sharjeel Imtiaz**
PhD Student, Tallinn University of Technology (TalTech)

- sharjeel.imtiaz@taltech.ee
- sharjeelimtiazprof@gmail.com
