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

// rtl/single_cycle/single_cycle_top.sv
`timescale 1ns/1ps
module single_cycle_top #(
  parameter IMEM_INIT = "rtl/common/programs/prog1.hex"
)(
  input  logic        clk,
  input  logic        rst_n
);
  // PC & instruction
  logic [31:0] pc, next_pc, instr;

  // fields
  logic [6:0] opcode;
  logic [4:0] rd, rs1, rs2;
  logic [2:0] funct3;
  logic [6:0] funct7;

  // control signals
  logic reg_write, memread, memwrite, memtoreg, alu_src;
  logic [3:0] alu_op;

  // datapath
  logic [31:0] rs1_data, rs2_data, alu_a, alu_b, alu_res, mem_rdata, wb_data;
  logic [31:0] imm_i;

  // modules
  program_counter pc_i(.clk(clk), .rst_n(rst_n), .next_pc(next_pc), .pc(pc));
  inst_memory #(.INIT_FILE(IMEM_INIT)) imem(.clk(clk), .addr(pc), .instr(instr));
  immgen imm_i_u(.instr(instr), .imm_i(imm_i), .imm_s(), .imm_b(), .imm_u(), .imm_j());

  // decode fields
  assign opcode = instr[6:0];
  assign rd     = instr[11:7];
  assign funct3 = instr[14:12];
  assign rs1    = instr[19:15];
  assign rs2    = instr[24:20];
  assign funct7 = instr[31:25];

  // control - minimal RV32I subset
  always_comb begin
    // defaults
    reg_write = 1'b0;
    memread   = 1'b0;
    memwrite  = 1'b0;
    memtoreg  = 1'b0;
    alu_src   = 1'b0;
    if (opcode == 7'b0110011) begin // R-type
      reg_write = 1'b1;
      alu_src = 1'b0;
      memtoreg = 1'b0;
      memread = 1'b0;
      memwrite = 1'b0;
    end else if (opcode == 7'b0010011) begin // I-type ALU imm
      reg_write = 1'b1;
      alu_src = 1'b1;
      memtoreg = 1'b0;
    end else if (opcode == 7'b0000011) begin // LW
      reg_write = 1'b1;
      memread = 1'b1;
      alu_src = 1'b1;
      memtoreg = 1'b1;
    end else if (opcode == 7'b0100011) begin // SW
      memwrite = 1'b1;
      alu_src = 1'b1;
    end
  end

  // regfile
  regfile rf(.clk(clk), .rst_n(rst_n), .we(reg_write), .rs1(rs1), .rs2(rs2), .rd(rd), .wd(wb_data),
             .rd1(rs1_data), .rd2(rs2_data));

  // alu control + alu
  alu_ctrl aluctrl(.opcode(opcode), .funct3(funct3), .funct7(funct7), .alu_op(alu_op));
  assign alu_a = rs1_data;
  assign alu_b = alu_src ? imm_i : rs2_data;
  alu alu_i(.a(alu_a), .b(alu_b), .alu_op(alu_op), .result(alu_res), .zero());

  // data memory
  data_memory dmem(.clk(clk), .rst_n(rst_n), .wr_en(memwrite), .rd_en(memread), .addr(alu_res), .wdata(rs2_data), .rdata(mem_rdata));

  // writeback mux
  assign wb_data = memtoreg ? mem_rdata : alu_res;

  // next PC (simple +4)
  assign next_pc = pc + 32'd4;

endmodule