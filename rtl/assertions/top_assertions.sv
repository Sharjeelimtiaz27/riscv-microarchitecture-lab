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
SVA assertion module for single_cycle_top -- integration-level properties.

These properties cross module boundaries: they prove that the control unit,
datapath, and memory interfaces are correctly wired together. Module-level
checkers prove each block in isolation; this checker proves the assembly.

All port names match single_cycle_top internal wire names, so the bind uses
.* for automatic port matching.

Properties cover:
  - PC alignment at the system level
  - PC +4 increment (no branches implemented in this design)
  - ALU source mux correctness (alu_src selects imm_i vs rs2_data)
  - Writeback mux correctness (memtoreg selects mem_rdata vs alu_res)
  - Control word correctness for R-type, I-type, Load, Store instructions
  - Mutual exclusion: memread and memwrite are never asserted together

Bound to    : single_cycle_top (bottom of this file)
Run with    : formal/prove_single_cycle.tcl
===============================================================================
*/

// rtl/assertions/top_assertions.sv
`timescale 1ns/1ps

module top_assertions (
    // ALL ports are input -- assertion module observes only, never drives
    input logic        clk,
    input logic        rst_n,
    // instruction path
    input logic [31:0] pc,
    input logic [31:0] instr,
    input logic [6:0]  opcode,
    // control signals
    input logic        reg_write,
    input logic        memread,
    input logic        memwrite,
    input logic        memtoreg,
    input logic        alu_src,
    // datapath
    input logic [31:0] alu_a,
    input logic [31:0] alu_b,
    input logic [31:0] alu_res,
    input logic [31:0] imm_i,
    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data,
    input logic [31:0] wb_data,
    input logic [31:0] mem_rdata
);

    //=========================================================================
    // PC PROPERTIES
    //=========================================================================

    // PC is always 4-byte aligned at the top level
    property p_pc_aligned;
        @(posedge clk) disable iff (!rst_n)
        pc[1:0] == 2'b00;
    endproperty
    assert property (p_pc_aligned)
        else $error("TOP FAIL: PC misaligned -- pc=%h", pc);

    // PC advances by exactly 4 each cycle (single-cycle, no branches in this design)
    property p_pc_plus4;
        @(posedge clk) disable iff (!rst_n)
        1'b1 |=> (pc == $past(pc,1) + 32'd4);
    endproperty
    assert property (p_pc_plus4)
        else $error("TOP FAIL: PC did not advance by 4 -- was=%h now=%h",
                    $past(pc,1), pc);

    //=========================================================================
    // ALU SOURCE MUX
    // alu_src=1: ALU B-operand comes from immediate (I-type, Load, Store)
    // alu_src=0: ALU B-operand comes from register rs2_data (R-type)
    //=========================================================================

    property p_alu_src_imm;
        @(posedge clk) disable iff (!rst_n)
        (alu_src == 1'b1) |-> (alu_b == imm_i);
    endproperty
    assert property (p_alu_src_imm)
        else $error("TOP FAIL: alu_b != imm_i when alu_src=1 -- alu_b=%h imm_i=%h",
                    alu_b, imm_i);

    property p_alu_src_reg;
        @(posedge clk) disable iff (!rst_n)
        (alu_src == 1'b0) |-> (alu_b == rs2_data);
    endproperty
    assert property (p_alu_src_reg)
        else $error("TOP FAIL: alu_b != rs2_data when alu_src=0");

    // ALU A-operand always comes from rs1_data (no second mux on A in this design)
    property p_alu_a_from_rs1;
        @(posedge clk) disable iff (!rst_n)
        alu_a == rs1_data;
    endproperty
    assert property (p_alu_a_from_rs1)
        else $error("TOP FAIL: alu_a != rs1_data");

    //=========================================================================
    // WRITEBACK MUX
    // memtoreg=1: write-back data comes from data memory (Load instruction)
    // memtoreg=0: write-back data comes from ALU result (R-type, I-type)
    //=========================================================================

    property p_wb_from_mem;
        @(posedge clk) disable iff (!rst_n)
        (memtoreg == 1'b1) |-> (wb_data == mem_rdata);
    endproperty
    assert property (p_wb_from_mem)
        else $error("TOP FAIL: wb_data != mem_rdata when memtoreg=1");

    property p_wb_from_alu;
        @(posedge clk) disable iff (!rst_n)
        (memtoreg == 1'b0) |-> (wb_data == alu_res);
    endproperty
    assert property (p_wb_from_alu)
        else $error("TOP FAIL: wb_data != alu_res when memtoreg=0");

    //=========================================================================
    // CONTROL WORD CORRECTNESS PER OPCODE
    // These are integration assertions: they prove the control unit generates
    // the correct signal bundle for each instruction class.
    //=========================================================================

    // R-type (0110011): reg_write=1, alu_src=0, memtoreg=0, memread=0, memwrite=0
    property p_rtype_ctrl;
        @(posedge clk) disable iff (!rst_n)
        (opcode == 7'b0110011) |->
            (reg_write && !alu_src && !memtoreg && !memread && !memwrite);
    endproperty
    assert property (p_rtype_ctrl)
        else $error("TOP FAIL: R-type control word wrong -- rw=%b src=%b mtr=%b mr=%b mw=%b",
                    reg_write, alu_src, memtoreg, memread, memwrite);

    // I-type ALU (0010011): reg_write=1, alu_src=1, memtoreg=0
    property p_itype_ctrl;
        @(posedge clk) disable iff (!rst_n)
        (opcode == 7'b0010011) |->
            (reg_write && alu_src && !memtoreg);
    endproperty
    assert property (p_itype_ctrl)
        else $error("TOP FAIL: I-type control word wrong");

    // Load (0000011): reg_write=1, memread=1, alu_src=1, memtoreg=1, memwrite=0
    property p_load_ctrl;
        @(posedge clk) disable iff (!rst_n)
        (opcode == 7'b0000011) |->
            (reg_write && memread && alu_src && memtoreg && !memwrite);
    endproperty
    assert property (p_load_ctrl)
        else $error("TOP FAIL: Load control word wrong");

    // Store (0100011): memwrite=1, reg_write=0, alu_src=1
    property p_store_ctrl;
        @(posedge clk) disable iff (!rst_n)
        (opcode == 7'b0100011) |->
            (memwrite && !reg_write && alu_src);
    endproperty
    assert property (p_store_ctrl)
        else $error("TOP FAIL: Store control word wrong");

    //=========================================================================
    // SAFETY: memread and memwrite can never be asserted at the same time.
    // Simultaneous read and write to the same address is undefined behavior.
    //=========================================================================

    property p_mem_rw_exclusive;
        @(posedge clk) disable iff (!rst_n)
        !(memread && memwrite);
    endproperty
    assert property (p_mem_rw_exclusive)
        else $error("TOP FAIL: memread and memwrite both asserted -- undefined memory behavior");

    //=========================================================================
    // COVER POINTS
    //=========================================================================

    cover property (@(posedge clk) disable iff (!rst_n) opcode == 7'b0110011); // R-type
    cover property (@(posedge clk) disable iff (!rst_n) opcode == 7'b0010011); // I-type
    cover property (@(posedge clk) disable iff (!rst_n) opcode == 7'b0000011); // Load
    cover property (@(posedge clk) disable iff (!rst_n) opcode == 7'b0100011); // Store
    cover property (@(posedge clk) disable iff (!rst_n) memtoreg == 1'b1);     // writeback from mem
    cover property (@(posedge clk) disable iff (!rst_n) reg_write == 1'b1);    // register written

endmodule

// =============================================================================
// BIND
// Bound at single_cycle_top. All port names match internal signal names in
// single_cycle_top, so .* performs automatic connection.
// =============================================================================
bind single_cycle_top top_assertions u_top_assert (.*);
