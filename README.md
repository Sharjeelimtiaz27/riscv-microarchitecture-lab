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

## Repo layout (what’s in this repo)
    riscv-microarchitecture-lab/
    ├── docs/
    │ ├── manuals/ # RISC-V reference links & annotated summaries
    │ ├── properties/ # Human explanations for each assertion/property
    │ └── weekly_notebooks/ # Week-by-week learning notes & answers
    ├── rtl/
    │ ├── common/ # Reusable modules: ALU, regfile, decoder, utils
    │ ├── single_cycle/ # Single-cycle reference core (educational baseline)
    │ └── pipeline/ # Pipelined core (IF/ID/EX/MEM/WB) and extensions
    ├── rtl/assertions/ # SVA files grouped by module / stage
    ├── tb/ # Testbenches and small smoke tests
    ├── tools/
    │ └── scripts/ # Helper scripts (run wrappers, build helpers)
    ├── .gitignore
    ├── README.md
    └── LICENSE


Short notes on folders:

- **docs/manuals/** — do NOT upload copyrighted PDFs. Instead add links to the RISC-V website and short annotated summaries or excerpts you write (these help teaching and interview prep).  
- **docs/properties/** — for each assertion add a markdown file describing: intent, why it matters, failure scenario, how to reproduce. This is the main teaching asset.  
- **docs/weekly_notebooks/** — each week has `week-XX.md` that lists objectives, answers to learning questions, files changed, tests run, and TODOs. This is your public learning journal.  
- **rtl/common/** — put ALU, regfile, decoder, immediate generator, and other reusable logic here. These modules will be used by both single-cycle and pipelined designs.  
- **rtl/single_cycle/** — a small single-cycle RV32I implementation (R-type, I-type basic subset). This is the canonical reference model you can later use for equivalence checking.  
- **rtl/pipeline/** — the real microarchitecture: staged registers, forwarding, hazard logic, branch handling. Add formal targets here once stable.  
- **rtl/assertions/** — keep SVA files next to modules so readers can easily map property → RTL. For every `.sv` assertion file also add a `.md` explanation under `docs/properties/`.  
- **tb/** — smoke tests and small directed tests. Later add pyuvm tests and golden-model comparators.  
- **tools/scripts/** — small wrappers for local Cadence runs, and any helper scripts.

---

## Weekly workflow (how we will work & document)

1. Create a branch `feat/week-XX` for weekly work.  
2. Implement RTL / assertions / testbenches for the week.  
3. Add `docs/weekly_notebooks/week-XX.md` with learning answers and test results.  
4. Open a PR to `dev` (review) and then merge `dev` → `main` after checks.  
5. Every assertion added must have a matching markdown doc in `docs/properties/`.

---

## License

This repository is licensed under the **MIT License** — free to use, adapt, and learn from. See `LICENSE`.

---

## Contact / Attribution

This repo is maintained by Sharjeel Imtiaz — use the Issues tab for questions, discussions, or suggested improvements. Pull requests and contributions are welcome.