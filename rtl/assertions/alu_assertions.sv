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
SVA assertion module for the ALU (alu.sv).
Module type  : COMBINATIONAL

Combinational assertion rules (strict):
  - NO @(posedge), NO ##N, NO $past(), NO disable iff
  - NO property/endproperty, NO assert property
  - All assertions live in one always_comb block
  - Boolean implication A -> B written as !A || B
  - Immediate assertions only

Port names match alu.sv exactly so the bind uses .* with no overrides.

Bound to    : alu (bottom of this file -- module-level bind)
Run with    : formal/prove_single_cycle.tcl
===============================================================================
*/

// rtl/assertions/alu_assertions.sv
`timescale 1ns/1ps

module alu_assertions (
    // --- NO clock, NO reset --- combinational module ---
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  alu_op,   // 0:ADD 1:SUB 2:AND 3:OR 4:XOR 5:SLT 6:SLL 7:SRL 8:SRA 9:SLTU
    input  logic [31:0] result,
    input  logic        zero
);

  // All assertions grouped in one always_comb block.
  // Evaluated at every simulation time step; JasperGold treats these as
  // combinational checks that must hold for all 2^97 input combinations.
  always_comb begin

    // -----------------------------------------------------------------------
    // a_alu_ZERO_FLAG: zero flag correct iff result is zero
    // -----------------------------------------------------------------------
    a_alu_ZERO_FLAG: assert (zero == (result == 32'd0))
      else $error("alu_ZERO_FLAG: zero=%b but result=%h", zero, result);

    // -----------------------------------------------------------------------
    // a_alu_ADD: alu_op=0 -> result == a + b  (32-bit unsigned wrap)
    // -----------------------------------------------------------------------
    a_alu_ADD: assert (!(alu_op == 4'd0) || (result == (a + b)))
      else $error("alu_ADD: ADD wrong -- a=%h b=%h result=%h expected=%h",
                  a, b, result, a + b);

    // -----------------------------------------------------------------------
    // a_alu_SUB: alu_op=1 -> result == a - b
    // -----------------------------------------------------------------------
    a_alu_SUB: assert (!(alu_op == 4'd1) || (result == (a - b)))
      else $error("alu_SUB: SUB wrong -- a=%h b=%h result=%h", a, b, result);

    // -----------------------------------------------------------------------
    // a_alu_AND: alu_op=2 -> result == a & b
    // -----------------------------------------------------------------------
    a_alu_AND: assert (!(alu_op == 4'd2) || (result == (a & b)))
      else $error("alu_AND: AND wrong");

    // -----------------------------------------------------------------------
    // a_alu_OR: alu_op=3 -> result == a | b
    // -----------------------------------------------------------------------
    a_alu_OR: assert (!(alu_op == 4'd3) || (result == (a | b)))
      else $error("alu_OR: OR wrong");

    // -----------------------------------------------------------------------
    // a_alu_XOR: alu_op=4 -> result == a ^ b
    // -----------------------------------------------------------------------
    a_alu_XOR: assert (!(alu_op == 4'd4) || (result == (a ^ b)))
      else $error("alu_XOR: XOR wrong");

    // -----------------------------------------------------------------------
    // a_alu_SLT_RANGE: SLT result is always 0 or 1 (comparison is boolean)
    // -----------------------------------------------------------------------
    a_alu_SLT_RANGE: assert (!(alu_op == 4'd5) || (result == 32'd0 || result == 32'd1))
      else $error("alu_SLT_RANGE: SLT result out of range -- got %h", result);

    // -----------------------------------------------------------------------
    // a_alu_SLT: alu_op=5 -> result == (signed a < signed b) ? 1 : 0
    // -----------------------------------------------------------------------
    a_alu_SLT: assert (!(alu_op == 4'd5) ||
                       (result == (($signed(a) < $signed(b)) ? 32'd1 : 32'd0)))
      else $error("alu_SLT: signed comparison wrong -- a=%h b=%h result=%h", a, b, result);

    // -----------------------------------------------------------------------
    // a_alu_SLL: alu_op=6 -> result == a << b[4:0]
    // RV32I: shift amount is only the lower 5 bits of rs2
    // -----------------------------------------------------------------------
    a_alu_SLL: assert (!(alu_op == 4'd6) || (result == (a << b[4:0])))
      else $error("alu_SLL: SLL wrong");

    // -----------------------------------------------------------------------
    // a_alu_SRL: alu_op=7 -> result == a >> b[4:0]  (logical, zero-fill)
    // -----------------------------------------------------------------------
    a_alu_SRL: assert (!(alu_op == 4'd7) || (result == (a >> b[4:0])))
      else $error("alu_SRL: SRL wrong");

    // -----------------------------------------------------------------------
    // a_alu_SRA: alu_op=8 -> result == $signed(a) >>> b[4:0]  (arithmetic, sign-fill)
    // -----------------------------------------------------------------------
    a_alu_SRA: assert (!(alu_op == 4'd8) || (result == 32'($signed(a) >>> b[4:0])))
      else $error("alu_SRA: SRA wrong");

    // -----------------------------------------------------------------------
    // a_alu_SLTU_RANGE: SLTU result is always 0 or 1
    // -----------------------------------------------------------------------
    a_alu_SLTU_RANGE: assert (!(alu_op == 4'd9) || (result == 32'd0 || result == 32'd1))
      else $error("alu_SLTU_RANGE: SLTU result out of range");

    // -----------------------------------------------------------------------
    // a_alu_SLTU: alu_op=9 -> result == (unsigned a < unsigned b) ? 1 : 0
    // -----------------------------------------------------------------------
    a_alu_SLTU: assert (!(alu_op == 4'd9) || (result == ((a < b) ? 32'd1 : 32'd0)))
      else $error("alu_SLTU: unsigned comparison wrong");

  end

endmodule

// =============================================================================
// BIND
// Bound at the alu module level. Port names (a, b, alu_op, result, zero)
// match alu.sv exactly -- .* handles all connections with no overrides.
// =============================================================================
bind alu alu_assertions u_alu_assert (.*);
