# Napkin Runbook — riscv-microarchitecture-lab

## Curation Rules
- Re-prioritize on every read.
- Keep recurring, high-value notes only.
- Max 10 items per category.
- Each item includes date + "Do instead".

---

## Execution and Validation (Highest Priority)

1. **[2026-04-06] Xcelium VCD generation fails silently**
   Do instead: always pass `-access +rwc` to xrun AND verify `$dumpfile`/`$dumpvars` appear in log output before claiming VCD was generated. Check `tail -n 100 artifacts/xrun_run.log` for dumpfile messages.

2. **[2026-04-06] ibex_csr uses logical not bitwise operators**
   Do instead: in ibex_csr conditions always write `&&` and `||`, never `&` and `|`.

3. **[2026-04-06] QuestaSim needs SV2012 flags on HPC**
   Do instead: pass `-sv12compat` or equivalent flag when compiling SystemVerilog on TalTech HPC QuestaSim.

4. **[2026-04-06] Trust-Hub benchmark citations were inaccurate**
   Do instead: always verify Trust-Hub citations manually before including in any paper or document.

---

## Shell and Command Reliability

1. **[2026-04-06] Always clean before recompile**
   Do instead: run `rm -rf work xcelium.d artifacts/* waves.vcd` before every fresh xrun invocation to avoid stale elaboration artifacts causing silent errors.

2. **[2026-04-06] PYTHONPATH must be set before xrun with pyuvm**
   Do instead: `export PYTHONPATH="$PWD/tb_pyuvm:$PYTHONPATH"` before invoking `run_pyuvm_xrun.sh`.

3. **[2026-04-06] IMEM path in single_cycle_top is hardcoded**
   Do instead: always override via parameter in the testbench: `#(.IMEM_INIT("/absolute/path/to/prog1.hex"))`. Relative paths fail under xrun from different working directories.

---

## Domain Behavior Guardrails

1. **[2026-04-06] No emojis anywhere in this repo**
   Do instead: never write emoji characters in any .sv, .py, .md, .tcl, .sh, or commit message in this project.

2. **[2026-04-06] Assertions belong in checker modules, not inline in RTL**
   Do instead: write SVA properties in `rtl/assertions/<module>_props.sv` as a separate checker module, then bind with `bind` statement or instantiate in TB.

3. **[2026-04-06] alu_ctrl is incomplete — SLT/SLL/SRL/SRA missing for R-type**
   Do instead: when testing instructions beyond ADD/SUB/AND/OR/XOR, extend alu_ctrl first; running unextended will produce alu_op=4'hF (illegal default).

---

## User Directives

1. **[2026-04-06] Mid-level learning target, not just AI-generated output**
   Do instead: when writing any new component (UVM, SVA, RTL), first explain the structure and intent so Sharjeel can replicate it independently, then produce the code.

2. **[2026-04-06] Repository policy: no emojis in any file or commit**
   Do instead: strip all emoji before generating any file content in this project.

3. **[2026-04-06] Processor target is RV64IM out-of-order 5-stage with Linux capability**
   Do instead: when any design decision comes up, bias toward RV64 correctness, SV39 MMU compatibility, and M/S/U privilege level requirements even in early phases.
