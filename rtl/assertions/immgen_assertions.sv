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
SVA assertion module for the immediate generator (immgen.sv).
Module type  : COMBINATIONAL

Combinational assertion rules (strict):
  - NO @(posedge), NO ##N, NO $past(), NO disable iff
  - NO property/endproperty, NO assert property
  - All assertions live in one always_comb block
  - Boolean implication A -> B written as !A || B
  - Immediate assertions only

Properties prove the encoding rules from RISC-V ISA spec Volume I Section 2.3:
  I-type: sign-extended from instr[31], payload = instr[31:20]
  S-type: sign-extended from instr[31], split across instr[31:25] and instr[11:7]
  B-type: sign-extended, imm[0]=0 (branch targets 2-byte aligned), scrambled bits
  U-type: imm[11:0]=0, upper 20 bits = instr[31:12] verbatim
  J-type: sign-extended, imm[0]=0 (jump targets 2-byte aligned), scrambled bits

Alignment invariants (imm_b[0]==0, imm_j[0]==0) are security properties:
a misassembled immediate with bit 0 set produces a misaligned PC on execution.

Port names match immgen.sv exactly so the bind uses .* with no overrides.

Bound to    : immgen (bottom of this file -- module-level bind)
Run with    : formal/prove_single_cycle.tcl
===============================================================================
*/

// rtl/assertions/immgen_assertions.sv
`timescale 1ns/1ps

module immgen_assertions (
    // --- NO clock, NO reset --- combinational module ---
    input  logic [31:0] instr,
    input  logic [31:0] imm_i,
    input  logic [31:0] imm_s,
    input  logic [31:0] imm_b,
    input  logic [31:0] imm_u,
    input  logic [31:0] imm_j
);

  always_comb begin

    // -----------------------------------------------------------------------
    // I-TYPE IMMEDIATE  imm_i = { {20{instr[31]}}, instr[31:20] }
    // -----------------------------------------------------------------------

    a_immgen_I_SIGN_EXT: assert (imm_i[31:12] == {20{instr[31]}})
      else $error("immgen_I_SIGN_EXT: I-type not sign-extended from instr[31]");

    a_immgen_I_PAYLOAD: assert (imm_i[11:0] == instr[31:20])
      else $error("immgen_I_PAYLOAD: I-type imm[11:0] wrong");

    // -----------------------------------------------------------------------
    // S-TYPE IMMEDIATE  imm_s = { {20{instr[31]}}, instr[31:25], instr[11:7] }
    // -----------------------------------------------------------------------

    a_immgen_S_SIGN_EXT: assert (imm_s[31:12] == {20{instr[31]}})
      else $error("immgen_S_SIGN_EXT: S-type not sign-extended from instr[31]");

    a_immgen_S_UPPER: assert (imm_s[11:5] == instr[31:25])
      else $error("immgen_S_UPPER: S-type imm[11:5] != instr[31:25]");

    a_immgen_S_LOWER: assert (imm_s[4:0] == instr[11:7])
      else $error("immgen_S_LOWER: S-type imm[4:0] != instr[11:7]");

    // -----------------------------------------------------------------------
    // B-TYPE IMMEDIATE
    // imm_b = { {19{instr[31]}}, instr[31], instr[7], instr[30:25],
    //            instr[11:8], 1'b0 }
    // SECURITY: imm_b[0] must be 0 -- branch targets must be 2-byte aligned
    // -----------------------------------------------------------------------

    a_immgen_B_LSB_ZERO: assert (imm_b[0] == 1'b0)
      else $error("immgen_B_LSB_ZERO: B-type imm[0] != 0 -- branch target alignment broken");

    a_immgen_B_SIGN_EXT: assert (imm_b[31:13] == {19{instr[31]}})
      else $error("immgen_B_SIGN_EXT: B-type not sign-extended from instr[31]");

    a_immgen_B_BIT12: assert (imm_b[12] == instr[31])
      else $error("immgen_B_BIT12: B-type imm[12] != instr[31]");

    a_immgen_B_BIT11: assert (imm_b[11] == instr[7])
      else $error("immgen_B_BIT11: B-type imm[11] != instr[7] (scrambled bit)");

    a_immgen_B_BITS10_5: assert (imm_b[10:5] == instr[30:25])
      else $error("immgen_B_BITS10_5: B-type imm[10:5] != instr[30:25]");

    a_immgen_B_BITS4_1: assert (imm_b[4:1] == instr[11:8])
      else $error("immgen_B_BITS4_1: B-type imm[4:1] != instr[11:8]");

    // -----------------------------------------------------------------------
    // U-TYPE IMMEDIATE  imm_u = { instr[31:12], 12'd0 }
    // -----------------------------------------------------------------------

    a_immgen_U_LOWER_ZERO: assert (imm_u[11:0] == 12'd0)
      else $error("immgen_U_LOWER_ZERO: U-type imm[11:0] not zero");

    a_immgen_U_UPPER: assert (imm_u[31:12] == instr[31:12])
      else $error("immgen_U_UPPER: U-type imm[31:12] != instr[31:12]");

    // -----------------------------------------------------------------------
    // J-TYPE IMMEDIATE
    // imm_j = { {11{instr[31]}}, instr[31], instr[19:12], instr[20],
    //            instr[30:21], 1'b0 }
    // SECURITY: imm_j[0] must be 0 -- jump targets must be 2-byte aligned
    // -----------------------------------------------------------------------

    a_immgen_J_LSB_ZERO: assert (imm_j[0] == 1'b0)
      else $error("immgen_J_LSB_ZERO: J-type imm[0] != 0 -- jump target alignment broken");

    a_immgen_J_SIGN_EXT: assert (imm_j[31:21] == {11{instr[31]}})
      else $error("immgen_J_SIGN_EXT: J-type not sign-extended from instr[31]");

    a_immgen_J_BIT20: assert (imm_j[20] == instr[31])
      else $error("immgen_J_BIT20: J-type imm[20] != instr[31]");

    a_immgen_J_BITS19_12: assert (imm_j[19:12] == instr[19:12])
      else $error("immgen_J_BITS19_12: J-type imm[19:12] != instr[19:12]");

    a_immgen_J_BIT11: assert (imm_j[11] == instr[20])
      else $error("immgen_J_BIT11: J-type imm[11] != instr[20] (scrambled bit)");

    a_immgen_J_BITS10_1: assert (imm_j[10:1] == instr[30:21])
      else $error("immgen_J_BITS10_1: J-type imm[10:1] != instr[30:21]");

  end

endmodule

// =============================================================================
// BIND
// Bound at the immgen module level. Port names (instr, imm_i, imm_s, imm_b,
// imm_u, imm_j) match immgen.sv exactly -- .* handles all connections.
// =============================================================================
bind immgen immgen_assertions u_immgen_assert (.*);
