# Pipelined RV64IM -- Synthesis and Physical Design Plan

**Document:** Synthesis and Physical Design Plan
**Version:** 0.1
**Applies to:** Planned pipeline processor

---

## Design Flow

```
RTL (SystemVerilog)
        |
        v
  Cadence Genus          -- Logic synthesis
        |
        v
  Gate-level netlist
        |
        v
  Cadence Innovus        -- Place and route
        |
        v
  GDS2 layout
```

---

## Synthesis Plan

### Constraints

| Parameter | Target |
|---|---|
| Clock frequency | TBD after RTL complete |
| Input delay | 20% of clock period |
| Output delay | 20% of clock period |
| Max fanout | 16 |
| Max transition | TBD |
| Technology | TBD (TalTech university library) |

### Script Location

`syn/pipeline_syn.tcl`

### Key Steps

1. Read all RTL source files
2. Elaborate top-level module
3. Apply SDC constraints
4. Run `syn_generic` (technology-independent optimisation)
5. Run `syn_map` (map to cell library)
6. Run `syn_opt` (post-mapping optimisation)
7. Write gate-level netlist
8. Generate reports: area, timing, power

### Expected Reports

| Report | File |
|---|---|
| Area | `syn/results/pipeline_area.rpt` |
| Timing (critical path) | `syn/results/pipeline_timing.rpt` |
| Power | `syn/results/pipeline_power.rpt` |
| Gate-level netlist | `syn/results/pipeline_mapped.v` |
| SDC for P&R | `syn/results/pipeline.sdc` |

---

## Place and Route Plan

### Script Location

`pnr/pipeline_pnr.tcl`

### Key Steps

1. Read synthesised netlist and SDC
2. Floorplan (aspect ratio, utilisation target TBD)
3. Power ring and mesh planning
4. Standard cell placement
5. Clock tree synthesis (CTS)
6. Post-CTS optimisation
7. Routing
8. Post-route optimisation and eco
9. Sign-off timing check
10. Export GDS2

### Expected Deliverables

| File | Description |
|---|---|
| `pnr/results/pipeline.gds` | Final GDS2 layout |
| `pnr/results/pipeline_signoff_timing.rpt` | Post-route timing report |
| `pnr/results/pipeline_drc.rpt` | Design rule check report |
| `pnr/results/pipeline_lvs.rpt` | Layout versus schematic report |

---

## Gate-Level Simulation

After synthesis, the gate-level netlist must be re-simulated with the same cocotb test suite used for RTL verification. The purpose is to verify that synthesis did not introduce functional changes.

```tcsh
cd tb_pyuvm
make SIM=xcelium VERILOG_SOURCES=../syn/results/pipeline_mapped.v
```

All tests must achieve the same PASS result as RTL simulation.
