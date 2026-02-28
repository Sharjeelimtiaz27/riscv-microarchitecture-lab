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

// rtl/common/regfile.sv
`timescale 1ns/1ps
module regfile (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         we,      // write enable (write-back)
  input  logic [4:0]   rs1,
  input  logic [4:0]   rs2,
  input  logic [4:0]   rd,
  input  logic [31:0]  wd,
  output logic [31:0]  rd1,
  output logic [31:0]  rd2
);
  logic [31:0] regs [31];

  // Reads are combinational (architectural semantics: x0 reads 0)
  assign rd1 = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
  assign rd2 = (rs2 == 5'd0) ? 32'd0 : regs[rs2];

  // Optional simulation init: zero regs for deterministic sims
  initial begin
    integer i;
    for (i = 0; i < 32; i = i + 1) regs[i] = 32'd0;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      integer j;
      for (j = 0; j < 32; j = j + 1) regs[j] <= 32'd0;
    end else begin
      // Only write when we is asserted and rd != x0
      if (we && (rd != 5'd0)) regs[rd] <= wd;
      // ensure x0 remains zero (defensive)
      regs[0] <= 32'd0;
    end
  end
endmodule