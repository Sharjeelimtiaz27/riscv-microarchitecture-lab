/*
===============================================================================
Project      : riscv-microarchitecture-lab
Testbench    : single_cycle_smoke_tb_waves.sv
Author       : Sharjeel Imtiaz
Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
Year         : 2026
Version      : v1.0 (Week-01 Simulation TB - VCD + debug probes)

Description  :
Refined smoke testbench for single-cycle RV32I top.
- Dumps waves.vcd (portable)
- Exposes internal signals via debug wires so they appear in the VCD
- Timeout guard to avoid runaway sims
- Simple smoke check (uses hierarchical regfile reference for quick verification)
===============================================================================
*/

`timescale 1ns/1ps

module single_cycle_smoke_tb;

  logic clk;
  logic rst_n;

  // Clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // DUT
  single_cycle_top #(
    .IMEM_INIT("/home/sharjeel/sharjeelphd/Research/riscv-microarchitecture-lab/rtl/common/programs/prog1.hex")
  ) dut (
    .clk(clk),
    .rst_n(rst_n)
  );

  // =============================
  // Explicit debug signals
  // =============================

  // PC and instruction
  wire [31:0] pc_dbg    = dut.pc;
  wire [31:0] instr_dbg = dut.instr;

  // ALU & writeback
  wire [31:0] alu_dbg   = dut.alu_res;
  wire [31:0] wb_dbg    = dut.wb_data;

  // Register file (first few)
  wire [31:0] r0_dbg = dut.rf.regs[0];
  wire [31:0] r1_dbg = dut.rf.regs[1];
  wire [31:0] r2_dbg = dut.rf.regs[2];
  wire [31:0] r3_dbg = dut.rf.regs[3];
  wire [31:0] r4_dbg = dut.rf.regs[4];

  // =============================
  // Dump waves
  // =============================
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, single_cycle_smoke_tb);
  end

  // =============================
  // Test sequence
  // =============================
  initial begin
    rst_n = 0;
    #12 rst_n = 1;

    #200;

    $display("x1=%0d x2=%0d x3=%0d", r1_dbg, r2_dbg, r3_dbg);

    if (r1_dbg == 5 && r2_dbg == 7 && r3_dbg == 12)
      $display("SMOKE PASS");
    else
      $display("SMOKE FAIL");

    #10 $finish;
  end

endmodule
