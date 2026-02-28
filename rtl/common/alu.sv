/*
===============================================================================
Project      : riscv-microarchitecture-lab
Author       : Sharjeel Imtiaz
Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
Year         : 2026
Version      : v1.0 (Single-Cycle RV32I Foundation)

Contact      : sharjeel.imtiaz@taltech.ee
               sharjeelimtiazprof@gmail.com

Description  :
This file is part of the riscv-microarchitecture-lab project, a structured
research and teaching initiative focused on designing, verifying, and
formally reasoning about RISC-V microarchitectures.

The repository documents the progressive development of:
- A single-cycle RV32I processor
- A pipelined RV32IMC processor
- Assertion-based verification
- Formal verification and security-oriented microarchitectural analysis

Notes        :
- The design is intentionally modular to enable reuse across
  single-cycle and pipelined implementations.
- Formal properties and assertions are maintained in separate files.
- This project serves both research documentation and educational purposes.


===============================================================================
*/

// rtl/common/alu.sv
`timescale 1ns/1ps
module alu (
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  logic [3:0]  alu_op,   // 0:ADD,1:SUB,2:AND,3:OR,4:XOR,5:SLT,6:SLL,7:SRL,8:SRA
  output logic [31:0] result,
  output logic        zero
);
  always_comb begin
    unique case (alu_op)
      4'd0: result = a + b;            // ADD
      4'd1: result = a - b;            // SUB
      4'd2: result = a & b;            // AND
      4'd3: result = a | b;            // OR
      4'd4: result = a ^ b;            // XOR
      4'd5: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLT
      4'd6: result = a << b[4:0];      // SLL
      4'd7: result = a >> b[4:0];      // SRL logical
      4'd8: result = $signed(a) >>> b[4:0]; // SRA arithmetic
      default: result = 32'h00000000;  // safe default
    endcase
  end

  assign zero = (result == 32'd0);
endmodule