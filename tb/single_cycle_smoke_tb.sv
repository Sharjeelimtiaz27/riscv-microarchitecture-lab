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

module single_cycle_smoke_tb_waves;
  // clock & reset
  logic clk;
  logic rst_n;

  // parameters
  localparam int MAX_CYCLES = 100000;

  // clock generation (10 ns period)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // instantiate DUT (point IMEM_INIT to your program hex path if needed)
  single_cycle_top #(.IMEM_INIT("rtl/common/programs/prog1.hex")) dut (
    .clk(clk),
    .rst_n(rst_n)
  );

  // --------------------------
  // Debug probe wires (TB scope)
  // these create named waveform signals referencing internal DUT nets
  // --------------------------
  // basic datapath probes
  wire [31:0] dbg_pc    = dut.pc;
  wire [31:0] dbg_instr = dut.instr;
  wire [31:0] dbg_alu   = dut.alu_res;
  wire [31:0] dbg_wb    = dut.wb_data;

  // expose first 16 regs (adjust if you want more)
  wire [31:0] dbg_r0  = dut.rf.regs[0];
  wire [31:0] dbg_r1  = dut.rf.regs[1];
  wire [31:0] dbg_r2  = dut.rf.regs[2];
  wire [31:0] dbg_r3  = dut.rf.regs[3];
  wire [31:0] dbg_r4  = dut.rf.regs[4];
  wire [31:0] dbg_r5  = dut.rf.regs[5];
  wire [31:0] dbg_r6  = dut.rf.regs[6];
  wire [31:0] dbg_r7  = dut.rf.regs[7];
  wire [31:0] dbg_r8  = dut.rf.regs[8];
  wire [31:0] dbg_r9  = dut.rf.regs[9];
  wire [31:0] dbg_r10 = dut.rf.regs[10];
  wire [31:0] dbg_r11 = dut.rf.regs[11];
  wire [31:0] dbg_r12 = dut.rf.regs[12];
  wire [31:0] dbg_r13 = dut.rf.regs[13];
  wire [31:0] dbg_r14 = dut.rf.regs[14];
  wire [31:0] dbg_r15 = dut.rf.regs[15];

  // --------------------------
  // Wave dump
  // --------------------------
  initial begin
    $display("[%0t] Starting simulation - wave dump to waves.vcd", $time);
    $dumpfile("waves.vcd");
    // Dump DUT plus explicit dbg signals. Some simulators hide hierarchy by default;
    // explicit dumpvars ensures these appear in VCD.
    $dumpvars(0, dut);
    $dumpvars(0, dbg_pc, dbg_instr, dbg_alu, dbg_wb,
                 dbg_r0, dbg_r1, dbg_r2, dbg_r3, dbg_r4, dbg_r5, dbg_r6, dbg_r7,
                 dbg_r8, dbg_r9, dbg_r10, dbg_r11, dbg_r12, dbg_r13, dbg_r14, dbg_r15);
  end

  // --------------------------
  // Test control / check / timeout
  // --------------------------
  integer cycle_count;
  initial begin
    // apply reset
    rst_n = 0;
    cycle_count = 0;
    #12 rst_n = 1; // release reset a bit after clock starts

    // wait / monitor
    @(posedge clk);
    while (cycle_count < MAX_CYCLES) begin
      cycle_count = cycle_count + 1;
      // perform smoke check at a heuristic cycle (program is short)
      if (cycle_count == 20) begin
        $display("[%0t] --- checking registers at cycle %0d ---", $time, cycle_count);
        $display("[%0t] REG[1]=%0d, REG[2]=%0d, REG[3]=%0d", $time, dut.rf.regs[1], dut.rf.regs[2], dut.rf.regs[3]);
        if (dut.rf.regs[1] === 32'd5 && dut.rf.regs[2] === 32'd7 && dut.rf.regs[3] === 32'd12) begin
          $display("[%0t] SMOKE PASS: program executed correctly", $time);
        end else begin
          $display("[%0t] SMOKE FAIL: expected x1=5 x2=7 x3=12, got x1=%0d x2=%0d x3=%0d", $time, dut.rf.regs[1], dut.rf.regs[2], dut.rf.regs[3]);
        end
        #10 $finish;
      end
      @(posedge clk);
    end

    // timeout guard
    $display("[%0t] TIMEOUT: reached %0d cycles without meeting check. Aborting.", $time, MAX_CYCLES);
    $finish;
  end

endmodule
