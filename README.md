# riscv-microarchitecture-lab

A public research & teaching lab for designing, verifying, and formally reasoning about RISC-V microarchitecture.

This project focuses on:

- RTL design in SystemVerilog  
- Functional verification (UVM / pyuvm / cocotb)  
- SystemVerilog Assertions (SVA) and explanation docs  
- Formal verification and proof harnesses  
- Security-aware microarchitectural reasoning  
- Weekly learning notebooks (design + properties + exercises)

---

## Vision

This repository documents a structured journey:

1. Start from a single-cycle RV32I core.  
2. Move to a pipelined microarchitecture (5-stage, then extend).  
3. Add assertions and formal proofs for microarchitectural invariants.  
4. Build functional verification environments and golden-model checks.  
5. Explore security properties and information-flow proofs.

Each step includes:
- Clean, modular RTL (well-documented)  
- Assertions with plain-English explanations (for teaching)  
- Weekly technical notes and exercises (for you and others)

---

## Repository Structure

```
riscv-microarchitecture-lab/
├── docs/
│   ├── manuals/              # RISC-V reference links & annotated summaries
│   ├── properties/           # Human explanations for each assertion/property
│   └── weekly_notebooks/     # Week-by-week learning notes & answers
├── rtl/
│   ├── common/               # Reusable modules: ALU, regfile, decoder, utils
│   ├── single_cycle/         # Single-cycle reference core (educational baseline)
│   ├── pipeline/             # Pipelined core (IF/ID/EX/MEM/WB) and extensions
│   └── assertions/           # SVA files grouped by module / stage
├── tb/                       # Testbenches and small smoke tests
├── simulation_results/       # Test results and waveforms
├── tools/
│   └── scripts/              # Helper scripts (run wrappers, build helpers)
├── .gitignore
├── README.md
└── LICENSE
```

### Directory Details

| Directory | Purpose |
|-----------|---------|
| **docs/manuals/** | RISC-V reference links and annotated summaries (no copyrighted PDFs). Use this for teaching and interview prep. |
| **docs/properties/** | Markdown documentation for each assertion: intent, significance, failure scenarios, and reproduction steps. Core teaching asset. |
| **docs/weekly_notebooks/** | Public learning journal with `week-XX.md` files containing objectives, Q&A, file changes, test results, and TODOs. |
| **rtl/common/** | Shared RTL modules (ALU, register file, decoder, immediate generator) used by both single-cycle and pipelined designs. |
| **rtl/single_cycle/** | Educational single-cycle RV32I implementation (R-type, I-type basics). Serves as reference model for equivalence checking. |
| **rtl/pipeline/** | Production microarchitecture with staged registers, forwarding, hazard logic, and branch handling. Formal verification targets added after stabilization. |
| **rtl/assertions/** | SystemVerilog Assertions (SVA) files co-located with corresponding modules for easy property-to-RTL mapping. Each `.sv` file has a matching `.md` in `docs/properties/`. |
| **tb/** | Smoke tests and directed testbenches. Future: pyuvm tests and golden-model comparators. |
| **simulation_results/** | Simulation outputs, waveforms, and test reports. |
| **tools/scripts/** | Build helpers and local simulation run wrappers. |

---

## Development Workflow

1. **Create Feature Branch**: Start work with `git checkout -b feat/week-XX`
2. **Implement**: Write RTL, assertions, and testbenches for the week
3. **Document**: Add `docs/weekly_notebooks/week-XX.md` with learning answers and test results
4. **Review**: Open PR against `dev` branch for code review
5. **Merge**: After approvals, merge `dev` → `main` with CI/CD checks passing
6. **Assert & Document**: Every new assertion must have a corresponding markdown in `docs/properties/`

---

## Getting Started

### Prerequisites
- SystemVerilog simulator (ModelSim, VCS, or open-source alternatives)
- Python 3.8+ (for testbench utilities and scripts)
- Git for version control

### Quick Start
```bash
git clone https://github.com/Sharjeelimtiaz27/riscv-microarchitecture-lab.git
cd riscv-microarchitecture-lab
# See docs/weekly_notebooks/ for current progress
# Run: make sim (if available) or check tools/scripts/ for run commands
```

---

## Contributing

This is a public learning project. Contributions, improvements, and discussions are welcome!

- **Questions?** Open an issue in the Issues tab
- **Improvements?** Submit a pull request with clear documentation
- **Discussion?** Use discussions for broader topics and ideas

---

## License

This repository is licensed under the **MIT License** — free to use, adapt, and learn from. See `LICENSE` for details.

---

## Contact & Maintenance

**Maintained by**: Sharjeel Imtiaz  
**Last Updated**: 2026-02-28

For questions, discussions, or suggested improvements, please use the Issues tab. Pull requests and contributions are welcome!