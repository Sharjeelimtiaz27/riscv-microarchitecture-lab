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
SVA assertion module for the program counter (pc.sv, module program_counter).

The PC is a single 32-bit register that loads next_pc on every posedge
and resets to 0x00000000 on active-low reset. All four port names match
the program_counter module ports, so the bind uses .* with no overrides.

Alignment is a security property: a misaligned PC redirects execution into
the middle of an instruction word, which can be exploited to execute
unintended instruction fragments. In RV32I, PC[1:0] must always be 00.

Bound to    : program_counter (bottom of this file)
Run with    : formal/prove_single_cycle.tcl
===============================================================================
*/

// rtl/assertions/pc_assertions.sv
`timescale 1ns/1ps

module pc_assertions (
    // ALL ports are input -- assertion module observes only, never drives
    input logic        clk,
    input logic        rst_n,
    input logic [31:0] next_pc,
    input logic [31:0] pc
);

    //=========================================================================
    // RESET PROPERTIES
    //=========================================================================

    // PC resets to the RISC-V reset vector 0x00000000
    property p_reset_value;
        @(posedge clk)
        !rst_n |=> (pc == 32'h0000_0000);
    endproperty
    assert property (p_reset_value)
        else $error("PC FAIL: PC not 0 while in reset -- pc=%h", pc);

    // At the posedge where reset deasserts, PC is still 0.
    // Uses |-> (same cycle): the async reset holds pc=0 until posedge, so the
    // sampled value is 0. |=> would check the NEXT cycle when pc has advanced to 4.
    property p_rose_reset_pc_zero;
        @(posedge clk)
        $rose(rst_n) |-> (pc == 32'h0000_0000);
    endproperty
    assert property (p_rose_reset_pc_zero)
        else $error("PC FAIL: PC not 0 at reset deassert cycle");

    //=========================================================================
    // REGISTER BEHAVIOR
    //=========================================================================

    // PC is a D flip-flop: captures next_pc on every posedge out of reset
    property p_pc_captures_next_pc;
        @(posedge clk) disable iff (!rst_n)
        1'b1 |=> (pc == $past(next_pc, 1));
    endproperty
    assert property (p_pc_captures_next_pc)
        else $error("PC FAIL: pc(%h) != past_next_pc(%h)", pc, $past(next_pc, 1));

    //=========================================================================
    // ALIGNMENT INVARIANT (also a security property)
    //=========================================================================

    // PC bits [1:0] must always be 00 in RV32I (instructions are 4-byte aligned).
    // Reset initialises PC to 0 (aligned). The single-cycle design adds 4 each
    // cycle, preserving alignment. This property proves the invariant holds for
    // all reachable states across the entire execution.
    property p_pc_aligned;
        @(posedge clk) disable iff (!rst_n)
        pc[1:0] == 2'b00;
    endproperty
    assert property (p_pc_aligned)
        else $error("PC FAIL: misaligned PC -- pc=%h, pc[1:0]=%b", pc, pc[1:0]);

    // next_pc must also be aligned to preserve the invariant on the next cycle
    property p_next_pc_aligned;
        @(posedge clk) disable iff (!rst_n)
        next_pc[1:0] == 2'b00;
    endproperty
    assert property (p_next_pc_aligned)
        else $error("PC FAIL: misaligned next_pc -- next_pc=%h", next_pc);

    //=========================================================================
    // COVER POINTS
    //=========================================================================

    cover property (@(posedge clk) disable iff (!rst_n) (pc > 32'd0));
    cover property (@(posedge clk) (pc == 32'h0000_0000));
    cover property (@(posedge clk) disable iff (!rst_n) $changed(pc));
    cover property (@(posedge clk) disable iff (!rst_n) (pc == 32'h0000_0040)); // 16th instruction

endmodule

// =============================================================================
// BIND
// All four ports (clk, rst_n, next_pc, pc) match program_counter port names.
// .* performs automatic connection with no explicit overrides needed.
// =============================================================================
bind program_counter pc_assertions u_pc_assert (.*);
