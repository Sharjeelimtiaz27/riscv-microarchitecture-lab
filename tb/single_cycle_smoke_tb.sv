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

// tb/single_cycle_smoke_tb_waves.sv
`timescale 1ns/1ps
module single_cycle_smoke_tb_waves;
  logic clk;
  logic rst_n;

  // parameters: how many cycles to run before timeout
  localparam int MAX_CYCLES = 1000;

  // clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 10ns period
  end

  // instantiate DUT with small program (prog1.hex)
  single_cycle_top #(.IMEM_INIT("rtl/common/programs/prog1.hex")) dut (.clk(clk), .rst_n(rst_n));

  // Wave dump: portable VCD and friendly display
  initial begin
    $display("Starting simulation - wave dump to waves.vcd (portable).");
    // Portable VCD
    $dumpfile("waves.vcd");
    $dumpvars(0, dut);

    // Note: when running with xrun you can also request FSDB via simulator flags:
    // tools/scripts/run_cadence.sh ... --waves
  end

  // test progress / timeout
  integer cycle_count;
  initial begin
    rst_n = 0;
    cycle_count = 0;
    #12 rst_n = 1; // release reset

    // wait some cycles for program to execute (the program is short)
    // We monitor cycle_count to avoid infinite sim runs.
    @(posedge clk);
    while (cycle_count < MAX_CYCLES) begin
      cycle_count = cycle_count + 1;
      // small heuristic: after a few cycles, we check registers
      if (cycle_count == 20) begin
        $display("--- checking registers at cycle %0d ---", cycle_count);
        $display("REG[1]=%0d, REG[2]=%0d, REG[3]=%0d", dut.rf.regs[1], dut.rf.regs[2], dut.rf.regs[3]);
        if (dut.rf.regs[1] === 32'd5 && dut.rf.regs[2] === 32'd7 && dut.rf.regs[3] === 32'd12) begin
          $display("SMOKE PASS: program executed correctly");
        end else begin
          $display("SMOKE FAIL: expected x1=5 x2=7 x3=12, got x1=%0d x2=%0d x3=%0d", dut.rf.regs[1], dut.rf.regs[2], dut.rf.regs[3]);
        end
        // finish gracefully
        #10 $finish;
      end
      @(posedge clk); // step
    end

    $display("TIMEOUT: reached %0d cycles without meeting check. Aborting.", MAX_CYCLES);
    $finish;
  end

endmodule