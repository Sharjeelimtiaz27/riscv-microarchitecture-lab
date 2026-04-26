# Single-Cycle RV32I -- Synthesis and Physical Design

**Document:** Synthesis and Physical Design Reference
**Version:** 1.0 (planned)
**Applies to:** `single_cycle_top` v1.0

---

## Status

This phase is planned. The RTL is complete and verified. Synthesis and place-and-route will be executed using the Cadence Genus and Innovus tools available on TalTech HPC.

---

## Target Technology

| Attribute | Value |
|---|---|
| Tool: Synthesis | Cadence Genus |
| Tool: Place and Route | Cadence Innovus |
| Technology Library | TBD (TalTech university cell library) |
| Target Frequency | TBD |
| Supply Voltage | TBD |
| Corner | TBD |

---

## Synthesis Script

Location: `syn/single_cycle_syn.tcl`

```tcl
read_hdl -sv rtl/common/alu.sv
read_hdl -sv rtl/common/alu_ctrl.sv
read_hdl -sv rtl/common/regfile.sv
read_hdl -sv rtl/common/pc.sv
read_hdl -sv rtl/common/immgen.sv
read_hdl -sv rtl/common/inst_memory.sv
read_hdl -sv rtl/common/data_memory.sv
read_hdl -sv rtl/single_cycle/single_cycle_top.sv
elaborate single_cycle_top
read_sdc constraints/single_cycle.sdc
syn_generic
syn_map
syn_opt
write_hdl -mapped > syn/results/single_cycle_mapped.v
report_area   > syn/results/area.rpt
report_timing > syn/results/timing.rpt
report_power  > syn/results/power.rpt
```

---

## Constraints

Location: `syn/constraints/single_cycle.sdc` (to be written)

Key constraints:
- Clock period: TBD
- Input delay: TBD
- Output delay: TBD
- False paths: none expected for single-cycle design

---

## Place and Route Script

Location: `pnr/single_cycle_pnr.tcl` (to be written)

Steps:
1. Read synthesised netlist
2. Floorplan
3. Power planning
4. Placement
5. Clock tree synthesis
6. Routing
7. Export GDS2

---

## Expected Deliverables

| File | Description |
|---|---|
| `syn/results/single_cycle_mapped.v` | Gate-level netlist |
| `syn/results/area.rpt` | Area report (cell count, total area) |
| `syn/results/timing.rpt` | Timing report (critical path, slack) |
| `syn/results/power.rpt` | Power report |
| `pnr/results/single_cycle.gds` | Final GDS2 layout |
