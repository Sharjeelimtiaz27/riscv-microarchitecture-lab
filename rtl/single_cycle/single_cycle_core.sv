/*
===============================================================================
Project      : riscv-microarchitecture-lab
Author       : Sharjeel Imtiaz
Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
Year         : 2026
Version      : v1.0 (Single-Cycle RV32I Core -- synthesis target)

Contact      : sharjeel.imtiaz@taltech.ee
               sharjeelimtiazprof@gmail.com

Description  :
Synthesis-ready single-cycle RV32I CORE.

This is single_cycle_top WITHOUT the instruction and data memories. The
memories are exposed as port interfaces instead of being instantiated inside.

WHY THIS MODULE EXISTS
----------------------
single_cycle_top embeds inst_memory and data_memory as internal modules.
The 0.18um standard cell library has no RAM compiler, so Genus black-boxes
those memory arrays. A black-boxed memory has undefined outputs, so `instr`
and `mem_rdata` get tied to 0, and constant propagation then deletes the
entire datapath (decoder, register file, ALU). Synthesizing single_cycle_top
produced only the PC -- 30 flip-flops, everything else constant 0.

The fix is the standard SoC methodology: the processor CORE is synthesized as
logic, and the memories are separate SRAM hard macros connected through ports.
Here, `imem_rdata` and `dmem_rdata` are primary INPUT ports. Synthesis treats
input ports as free driven signals, so the full datapath is preserved.

ROLES
-----
single_cycle_top  : simulation + formal verification target (memories inside)
single_cycle_core : synthesis + place-and-route target (memories as ports)

The logic below is identical to single_cycle_top's datapath. Only the memory
instances are replaced by port connections.

Memory interface (single-cycle, combinational read assumed by the core):
  imem_addr  (out) : instruction fetch address = PC
  imem_rdata (in)  : instruction word from external instruction memory
  dmem_addr  (out) : data access address = ALU result
  dmem_wdata (out) : store data = rs2
  dmem_we    (out) : data write enable
  dmem_re    (out) : data read enable
  dmem_rdata (in)  : load data from external data memory
===============================================================================
*/

// rtl/single_cycle/single_cycle_core.sv
`timescale 1ns/1ps
module single_cycle_core (
  input  logic        clk,
  input  logic        rst_n,

  // Instruction memory interface
  output logic [31:0] imem_addr,    // = PC
  input  logic [31:0] imem_rdata,   // = instruction word

  // Data memory interface
  output logic [31:0] dmem_addr,    // = ALU result (load/store address)
  output logic [31:0] dmem_wdata,   // = rs2 data (store data)
  output logic        dmem_we,      // = memwrite
  output logic        dmem_re,      // = memread
  input  logic [31:0] dmem_rdata,   // = load data

  // Debug / trace outputs
  output logic [31:0] dbg_pc,
  output logic        dbg_reg_write,
  output logic [4:0]  dbg_rd,
  output logic [31:0] dbg_wb_data
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

  // program counter
  program_counter pc_i(.clk(clk), .rst_n(rst_n), .next_pc(next_pc), .pc(pc));

  // Instruction memory is EXTERNAL: drive address out, take instruction in
  assign imem_addr = pc;
  assign instr     = imem_rdata;

  // immediate generator
  immgen imm_i_u(.instr(instr), .imm_i(imm_i), .imm_s(), .imm_b(), .imm_u(), .imm_j());

  // decode fields
  assign opcode = instr[6:0];
  assign rd     = instr[11:7];
  assign funct3 = instr[14:12];
  assign rs1    = instr[19:15];
  assign rs2    = instr[24:20];
  assign funct7 = instr[31:25];

  // control - minimal RV32I subset (identical to single_cycle_top)
  always_comb begin
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

  // Data memory is EXTERNAL: drive interface out, take read data in
  assign dmem_addr  = alu_res;
  assign dmem_wdata = rs2_data;
  assign dmem_we    = memwrite;
  assign dmem_re    = memread;
  assign mem_rdata  = dmem_rdata;

  // writeback mux
  assign wb_data = memtoreg ? mem_rdata : alu_res;

  // next PC (simple +4)
  assign next_pc = pc + 32'd4;

  // debug / trace outputs
  assign dbg_pc        = pc;
  assign dbg_reg_write = reg_write;
  assign dbg_rd        = rd;
  assign dbg_wb_data   = wb_data;

endmodule
