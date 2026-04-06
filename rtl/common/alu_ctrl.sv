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

// rtl/common/alu_ctrl.sv

`timescale 1ns/1ps
module alu_ctrl (
  input  logic [6:0] opcode,
  input  logic [2:0] funct3,
  input  logic [6:0] funct7,
  output logic [3:0] alu_op
);
  // ALU control: decodes opcode + funct3 + funct7 into a 4-bit ALU operation code.
  // Covers all RV32I R-type and I-type ALU instructions.
  always_comb begin
    alu_op = 4'hF; // default: illegal operation

    if (opcode == 7'b0110011) begin // R-type
      unique case ({funct7, funct3})
        {7'b0000000, 3'b000}: alu_op = 4'd0; // ADD
        {7'b0100000, 3'b000}: alu_op = 4'd1; // SUB
        {7'b0000000, 3'b111}: alu_op = 4'd2; // AND
        {7'b0000000, 3'b110}: alu_op = 4'd3; // OR
        {7'b0000000, 3'b100}: alu_op = 4'd4; // XOR
        {7'b0000000, 3'b010}: alu_op = 4'd5; // SLT
        {7'b0000000, 3'b001}: alu_op = 4'd6; // SLL
        {7'b0000000, 3'b101}: alu_op = 4'd7; // SRL
        {7'b0100000, 3'b101}: alu_op = 4'd8; // SRA
        {7'b0000000, 3'b011}: alu_op = 4'd9; // SLTU
        default:              alu_op = 4'hF;
      endcase

    end else if (opcode == 7'b0010011) begin // I-type ALU immediate
      unique case (funct3)
        3'b000: alu_op = 4'd0; // ADDI
        3'b111: alu_op = 4'd2; // ANDI
        3'b110: alu_op = 4'd3; // ORI
        3'b100: alu_op = 4'd4; // XORI
        3'b010: alu_op = 4'd5; // SLTI
        3'b011: alu_op = 4'd9; // SLTIU
        3'b001: alu_op = 4'd6; // SLLI  (funct7=0000000)
        3'b101: alu_op = (funct7 == 7'b0100000) ? 4'd8 : 4'd7; // SRAI / SRLI
        default: alu_op = 4'hF;
      endcase

    end else if (opcode == 7'b0000011) begin // Load (LW etc.) -- address = rs1 + imm
      alu_op = 4'd0; // ADD

    end else if (opcode == 7'b0100011) begin // Store (SW etc.) -- address = rs1 + imm
      alu_op = 4'd0; // ADD

    end else if (opcode == 7'b1100011) begin // Branch -- compare rs1 and rs2
      alu_op = 4'd1; // SUB (zero flag used for BEQ/BNE)
    end
  end
endmodule