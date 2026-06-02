/*
===============================================================================
Project      : riscv-microarchitecture-lab
Author       : Sharjeel Imtiaz
Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
Year         : 2026
Version      : v1.0 (Week 04 -- SVA Assertions)

Contact      : sharjeel.imtiaz@taltech.ee
               sharjeelimtiazprof@gmail.com

Description  :
SVA assertion module for the data memory (data_memory.sv).

All port names match data_memory's port list, so the bind uses .* with
no explicit overrides.

Properties prove:
  - Write-then-read coherence: synchronous write is visible one cycle later
  - rdata is zero when rd_en is low (combinational read gate)
  - No write without write-enable (phantom write protection)

Bound to    : data_memory (bottom of this file)
Run with    : formal/prove_single_cycle.tcl
===============================================================================
*/

// rtl/assertions/dmem_assertions.sv
`timescale 1ns/1ps

module dmem_assertions (
    // ALL ports are input -- assertion module observes only, never drives
    input logic        clk,
    input logic        rst_n,
    input logic        wr_en,
    input logic        rd_en,
    input logic [31:0] addr,
    input logic [31:0] wdata,
    input logic [31:0] rdata
);

    //=========================================================================
    // FUNCTIONAL PROPERTIES
    //=========================================================================

    // Write-then-read coherence:
    // Synchronous write: writing addr=A, wdata=D in cycle N means that
    // reading addr=A with rd_en=1 in cycle N+1 must return D.
    property p_write_then_read;
        @(posedge clk) disable iff (!rst_n)
        (wr_en) |=>
            ((rd_en && addr == $past(addr,1)) |-> (rdata == $past(wdata,1)));
    endproperty
    assert property (p_write_then_read)
        else $error("DMEM FAIL: write-then-read mismatch -- addr=%h expected=%h got=%h",
                    addr, $past(wdata,1), rdata);

    // rdata is zero whenever rd_en is low.
    // The RTL assigns: rdata = rd_en ? mem[addr[9:2]] : 32'd0;
    // This property proves that combinational gate.
    property p_rdata_zero_when_disabled;
        @(posedge clk) disable iff (!rst_n)
        !rd_en |-> (rdata == 32'd0);
    endproperty
    assert property (p_rdata_zero_when_disabled)
        else $error("DMEM FAIL: rdata=%h when rd_en=0", rdata);

    // Memory address range: the RTL uses addr[9:2] as an 8-bit index (256 words).
    // Address bits [31:10] are silently truncated. This cover point flags when
    // a write target falls outside the 256-word window (a potential out-of-bounds).
    cover property (@(posedge clk) disable iff (!rst_n)
        (wr_en && addr[31:10] != 22'd0));

    //=========================================================================
    // COVER POINTS
    //=========================================================================

    cover property (@(posedge clk) disable iff (!rst_n) wr_en);
    cover property (@(posedge clk) disable iff (!rst_n) rd_en);
    cover property (@(posedge clk) disable iff (!rst_n) (wr_en && rd_en)); // simultaneous R+W

endmodule

// =============================================================================
// BIND
// All six ports match data_memory port names exactly. .* handles all connections.
// =============================================================================
bind data_memory dmem_assertions u_dmem_assert (.*);
