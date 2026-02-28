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

// rtl/common/inst_memory.sv
`timescale 1ns/1ps
module inst_memory #(
  parameter INIT_FILE = ""
)(
  input  logic        clk,
  input  logic [31:0] addr,
  output logic [31:0] instr
);
  logic [31:0] mem [0:255];

  initial begin
    integer i;
    for (i=0; i<256; i=i+1) mem[i] = 32'd0;
    if (INIT_FILE != "") begin
      $display("IMEM: reading %0s", INIT_FILE);
      $readmemh(INIT_FILE, mem);
    end
  end

  assign instr = mem[addr[9:2]]; // word aligned
endmodule