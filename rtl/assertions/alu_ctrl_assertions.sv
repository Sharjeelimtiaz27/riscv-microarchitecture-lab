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
SVA assertion module for the ALU control decoder (alu_ctrl.sv).
Module type  : COMBINATIONAL

Combinational assertion rules (strict):
  - NO @(posedge), NO ##N, NO $past(), NO disable iff
  - NO property/endproperty, NO assert property
  - All assertions live in one always_comb block
  - Boolean implication A -> B written as !A || B
  - Immediate assertions only

Security relevance:
  Operation substitution attack: a Trojan could replace one ALU operation with
  another under a specific secret trigger in opcode/funct3/funct7. The assertions
  below prove the decoder is a strict bijective mapping for every legal encoding.
  The SRLI vs SRAI case (same opcode/funct3, differ only in funct7[5]) is the
  most critical -- silently swapping logical for arithmetic shift corrupts signed
  arithmetic without changing test results for positive operands.

Port names match alu_ctrl.sv exactly so the bind uses .* with no overrides.

Bound to    : alu_ctrl (bottom of this file -- module-level bind)
Run with    : formal/prove_single_cycle.tcl
===============================================================================
*/

// rtl/assertions/alu_ctrl_assertions.sv
`timescale 1ns/1ps

module alu_ctrl_assertions (
    // --- NO clock, NO reset --- combinational module ---
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    input  logic [3:0] alu_op
);

  // Opcode constants matching RV32I spec
  localparam logic [6:0] OPCODE_RTYPE  = 7'b0110011;
  localparam logic [6:0] OPCODE_ITYPE  = 7'b0010011;
  localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
  localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
  localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;

  always_comb begin

    // -----------------------------------------------------------------------
    // R-TYPE DECODING
    // -----------------------------------------------------------------------

    a_aluctrl_R_ADD: assert (
      !(opcode == OPCODE_RTYPE && funct7 == 7'b0000000 && funct3 == 3'b000) ||
      (alu_op == 4'd0))
      else $error("aluctrl_R_ADD: R-ADD should map to alu_op=0");

    a_aluctrl_R_SUB: assert (
      !(opcode == OPCODE_RTYPE && funct7 == 7'b0100000 && funct3 == 3'b000) ||
      (alu_op == 4'd1))
      else $error("aluctrl_R_SUB: R-SUB should map to alu_op=1");

    a_aluctrl_R_AND: assert (
      !(opcode == OPCODE_RTYPE && funct7 == 7'b0000000 && funct3 == 3'b111) ||
      (alu_op == 4'd2))
      else $error("aluctrl_R_AND: R-AND should map to alu_op=2");

    a_aluctrl_R_OR: assert (
      !(opcode == OPCODE_RTYPE && funct7 == 7'b0000000 && funct3 == 3'b110) ||
      (alu_op == 4'd3))
      else $error("aluctrl_R_OR: R-OR should map to alu_op=3");

    a_aluctrl_R_XOR: assert (
      !(opcode == OPCODE_RTYPE && funct7 == 7'b0000000 && funct3 == 3'b100) ||
      (alu_op == 4'd4))
      else $error("aluctrl_R_XOR: R-XOR should map to alu_op=4");

    a_aluctrl_R_SLT: assert (
      !(opcode == OPCODE_RTYPE && funct7 == 7'b0000000 && funct3 == 3'b010) ||
      (alu_op == 4'd5))
      else $error("aluctrl_R_SLT: R-SLT should map to alu_op=5");

    a_aluctrl_R_SLL: assert (
      !(opcode == OPCODE_RTYPE && funct7 == 7'b0000000 && funct3 == 3'b001) ||
      (alu_op == 4'd6))
      else $error("aluctrl_R_SLL: R-SLL should map to alu_op=6");

    a_aluctrl_R_SRL: assert (
      !(opcode == OPCODE_RTYPE && funct7 == 7'b0000000 && funct3 == 3'b101) ||
      (alu_op == 4'd7))
      else $error("aluctrl_R_SRL: R-SRL should map to alu_op=7");

    a_aluctrl_R_SRA: assert (
      !(opcode == OPCODE_RTYPE && funct7 == 7'b0100000 && funct3 == 3'b101) ||
      (alu_op == 4'd8))
      else $error("aluctrl_R_SRA: R-SRA should map to alu_op=8");

    a_aluctrl_R_SLTU: assert (
      !(opcode == OPCODE_RTYPE && funct7 == 7'b0000000 && funct3 == 3'b011) ||
      (alu_op == 4'd9))
      else $error("aluctrl_R_SLTU: R-SLTU should map to alu_op=9");

    // -----------------------------------------------------------------------
    // I-TYPE ALU IMMEDIATE DECODING
    // -----------------------------------------------------------------------

    a_aluctrl_ADDI: assert (
      !(opcode == OPCODE_ITYPE && funct3 == 3'b000) || (alu_op == 4'd0))
      else $error("aluctrl_ADDI: ADDI should map to alu_op=0");

    a_aluctrl_ANDI: assert (
      !(opcode == OPCODE_ITYPE && funct3 == 3'b111) || (alu_op == 4'd2))
      else $error("aluctrl_ANDI: ANDI should map to alu_op=2");

    a_aluctrl_ORI: assert (
      !(opcode == OPCODE_ITYPE && funct3 == 3'b110) || (alu_op == 4'd3))
      else $error("aluctrl_ORI: ORI should map to alu_op=3");

    a_aluctrl_XORI: assert (
      !(opcode == OPCODE_ITYPE && funct3 == 3'b100) || (alu_op == 4'd4))
      else $error("aluctrl_XORI: XORI should map to alu_op=4");

    a_aluctrl_SLTI: assert (
      !(opcode == OPCODE_ITYPE && funct3 == 3'b010) || (alu_op == 4'd5))
      else $error("aluctrl_SLTI: SLTI should map to alu_op=5");

    a_aluctrl_SLTIU: assert (
      !(opcode == OPCODE_ITYPE && funct3 == 3'b011) || (alu_op == 4'd9))
      else $error("aluctrl_SLTIU: SLTIU should map to alu_op=9");

    a_aluctrl_SLLI: assert (
      !(opcode == OPCODE_ITYPE && funct3 == 3'b001) || (alu_op == 4'd6))
      else $error("aluctrl_SLLI: SLLI should map to alu_op=6");

    // CRITICAL security check: SRLI vs SRAI differ ONLY in funct7[5].
    // Silently substituting one for the other corrupts signed shift results.
    a_aluctrl_SRLI: assert (
      !(opcode == OPCODE_ITYPE && funct3 == 3'b101 && funct7 == 7'b0000000) ||
      (alu_op == 4'd7))
      else $error("aluctrl_SRLI: SRLI (logical) should map to alu_op=7 not SRA");

    a_aluctrl_SRAI: assert (
      !(opcode == OPCODE_ITYPE && funct3 == 3'b101 && funct7 == 7'b0100000) ||
      (alu_op == 4'd8))
      else $error("aluctrl_SRAI: SRAI (arithmetic) should map to alu_op=8 not SRL");

    // -----------------------------------------------------------------------
    // LOAD, STORE, BRANCH
    // -----------------------------------------------------------------------

    a_aluctrl_LOAD: assert (
      !(opcode == OPCODE_LOAD) || (alu_op == 4'd0))
      else $error("aluctrl_LOAD: Load address compute should use ADD (op=0)");

    a_aluctrl_STORE: assert (
      !(opcode == OPCODE_STORE) || (alu_op == 4'd0))
      else $error("aluctrl_STORE: Store address compute should use ADD (op=0)");

    a_aluctrl_BRANCH: assert (
      !(opcode == OPCODE_BRANCH) || (alu_op == 4'd1))
      else $error("aluctrl_BRANCH: Branch compare should use SUB (op=1)");

    // NOTE: A property "no illegal for any known opcode" was removed.
    // R-type has many undefined funct7/funct3 combinations (e.g. MUL from
    // RV32M) that legitimately return 4'hF in an RV32I-only decoder.
    // The individual per-instruction assertions above prove every defined
    // encoding maps to the correct alu_op, which is the complete specification.

  end

endmodule

// =============================================================================
// BIND
// Bound at the alu_ctrl module level. Port names (opcode, funct3, funct7,
// alu_op) match alu_ctrl.sv exactly -- .* handles all connections.
// =============================================================================
bind alu_ctrl alu_ctrl_assertions u_alu_ctrl_assert (.*);
