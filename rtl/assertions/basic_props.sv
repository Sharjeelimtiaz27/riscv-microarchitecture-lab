/*
===============================================================================
Project      : riscv-microarchitecture-lab
Author       : Sharjeel Imtiaz
Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
Year         : 2026
Version      : v1.0 (SVA basics)

Contact      : sharjeel.imtiaz@taltech.ee
               sharjeelimtiazprof@gmail.com

Description  :
Simple SVA checks for single-cycle core:
 - x0 immutability (no writes to x0)
 - basic decoder sanity example (opcode not zero when PC advanced)
===============================================================================
*/

`timescale 1ns/1ps

module basic_props_checker(
    input logic clk,
    input logic rst_n,
    input logic [4:0] rd,
    input logic reg_write,
    input logic [6:0] opcode,
    input logic [31:0] pc
);

  // x0 immutability: never write to rd==0
  property x0_immutable;
    @(posedge clk) disable iff (!rst_n)
    !(reg_write && (rd == 5'd0));
  endproperty
  assert property (x0_immutable) else $error("SVA FAIL: write to x0 detected");

  // when PC increments (simple check), instruction opcode should be not-zero
  property opcode_nonzero_after_fetch;
    @(posedge clk) disable iff (!rst_n)
    (pc != 32'd0) |-> (opcode != 7'd0);
  endproperty
  assert property (opcode_nonzero_after_fetch) else $warning("SVA WARN: opcode zero after PC advanced");

endmodule