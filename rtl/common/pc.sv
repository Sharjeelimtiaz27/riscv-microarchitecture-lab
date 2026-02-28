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
// rtl/common/pc.sv
`timescale 1ns/1ps
module program_counter (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [31:0] next_pc,
  output logic [31:0] pc
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) pc <= 32'h0000_0000;
    else pc <= next_pc;
  end
endmodule