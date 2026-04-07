/*
===============================================================================
Project      : riscv-microarchitecture-lab
Author       : Sharjeel Imtiaz
Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
Year         : 2026
Version      : v2.0 (comprehensive coverage program)

Contact      : sharjeel.imtiaz@taltech.ee
               sharjeelimtiazprof@gmail.com

Description  :
Comprehensive RV32I assembly test program designed to maximize functional
coverage of the single-cycle processor. The program exercises every major
RV32I instruction class, fills all destination register bins (x1-x31),
and uses all 32 architectural registers as rs1 source operands.

Coverage achieved:
  Opcode bins       : R-type, I-type ALU, Load, Store, Branch, JAL, JALR,
                      LUI, AUIPC (9 of 11; FENCE and SYSTEM not implemented)
  R-type ALU ops    : ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
  I-type ALU ops    : ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU
  Destination rd    : x1 through x31 (all 31 writable registers)
  Source rs1        : x0 through x31 (all 32 registers)

Execution flow:
  Instructions 1-32   : linear register computation
  Instructions 33-34  : LUI and AUIPC for opcode coverage (rd=x0)
  Instruction  35     : BEQ x1, x2 -- not taken (5 != 7), falls through
  Instruction  36     : JAL x0, +12 -- skips two NOPs, lands at instr 39
  Instruction  39     : ADDI x30, x0, 168 -- sets JALR target address
  Instruction  40     : JALR x0, 0(x30)  -- jumps to address 168 (instr 43)
  Instructions 43-61  : ADDI x0, xN, 0 instructions touch all remaining rs1
  Instructions 62-64  : NOP padding

Expected register values after full execution:
  x1=5  x2=7  x3=12  x4=13  x5=7   x6=4   x7=15  x8=11
  x9=384  x10=0  x11=0  x12=1  x13=1  x14=0  x15=12  x16=9
  x17=24  x18=6  x19=6  x20=1  x21=1  x22=12  x23=13  x24=7
  x25=4   x26=15  x27=11  x28=384  x29=4  x30=168  x31=9
===============================================================================
*/

    .section .text
    .globl _start
_start:

    # Phase 1: base register initialisation
    addi  x1,  x0,  5          # x1  = 5
    addi  x2,  x0,  7          # x2  = 7
    add   x3,  x1,  x2         # x3  = 12  (ADD)

    # Phase 2: R-type ALU -- all ten operations
    addi  x4,  x3,  1          # x4  = 13  (ADDI)
    sub   x5,  x3,  x1         # x5  = 7   (SUB)
    and   x6,  x3,  x2         # x6  = 4   (AND:  12 & 7)
    or    x7,  x3,  x2         # x7  = 15  (OR:   12 | 7)
    xor   x8,  x3,  x2         # x8  = 11  (XOR:  12 ^ 7)
    sll   x9,  x3,  x1         # x9  = 384 (SLL:  12 << 5)
    srl   x10, x3,  x1         # x10 = 0   (SRL:  12 >> 5 logical)
    sra   x11, x3,  x1         # x11 = 0   (SRA:  12 >> 5 arithmetic)
    slt   x12, x1,  x2         # x12 = 1   (SLT:  5 < 7 signed)
    sltu  x13, x1,  x2         # x13 = 1   (SLTU: 5 < 7 unsigned)

    # Phase 3: I-type ALU -- all nine operations
    andi  x14, x3,  3          # x14 = 0   (ANDI: 12 & 3)
    ori   x15, x3,  4          # x15 = 12  (ORI:  12 | 4)
    xori  x16, x3,  5          # x16 = 9   (XORI: 12 ^ 5)
    slli  x17, x3,  1          # x17 = 24  (SLLI: 12 << 1)
    srli  x18, x3,  1          # x18 = 6   (SRLI: 12 >> 1 logical)
    srai  x19, x3,  1          # x19 = 6   (SRAI: 12 >> 1 arithmetic)
    slti  x20, x1,  10         # x20 = 1   (SLTI:  5 < 10 signed)
    sltiu x21, x2,  10         # x21 = 1   (SLTIU: 7 < 10 unsigned)

    # Phase 4: memory -- store then load
    addi  x30, x0,  64         # x30 = 64  (byte address of data word)
    sw    x3,  0(x30)          # mem[64]  = 12
    lw    x22, 0(x30)          # x22 = 12  (LW)

    # Phase 5: cover destination registers x23-x31 with varied rs1
    addi  x23, x4,  0          # x23 = 13  (rs1=x4)
    addi  x24, x5,  0          # x24 = 7   (rs1=x5)
    addi  x25, x6,  0          # x25 = 4   (rs1=x6)
    addi  x26, x7,  0          # x26 = 15  (rs1=x7)
    addi  x27, x8,  0          # x27 = 11  (rs1=x8)
    addi  x28, x9,  0          # x28 = 384 (rs1=x9)
    addi  x29, x12, 3          # x29 = 4   (rs1=x12; 1+3=4)
    addi  x31, x13, 8          # x31 = 9   (rs1=x13; 1+8=9)

    # Phase 6: opcode coverage -- LUI and AUIPC (rd=x0, result discarded)
    lui   x0,  1               # opcode=LUI (rd discarded)
    auipc x0,  0               # opcode=AUIPC (rd discarded)

    # Phase 7: branch -- BEQ not taken (x1=5 != x2=7), then JAL forward
    beq   x1,  x2,  1f         # BEQ, not taken; fall through to JAL
    jal   x0,  2f              # JAL: jump to label 2 (skips two NOPs)
    nop                         # skipped by JAL
    nop                         # skipped by JAL
2:
    # Phase 8: JALR setup and execution
    addi  x30, x0,  168        # x30 = 168 = byte address of landing zone
    jalr  x0,  0(x30)          # JALR: jump to address 168 (label 3)
    nop                         # skipped by JALR
    nop                         # skipped by JALR
1:
    nop                         # forward target of BEQ (never actually reached)
3:
    # Phase 9: rs1 coverage sweep using ADDI x0, xN, 0
    # These instructions discard their result (rd=x0) and serve only to
    # register each remaining architectural register as an rs1 source.
    addi  x0,  x10, 0          # rs1=x10
    addi  x0,  x11, 0          # rs1=x11
    addi  x0,  x14, 0          # rs1=x14
    addi  x0,  x15, 0          # rs1=x15
    addi  x0,  x16, 0          # rs1=x16
    addi  x0,  x17, 0          # rs1=x17
    addi  x0,  x18, 0          # rs1=x18
    addi  x0,  x19, 0          # rs1=x19
    addi  x0,  x20, 0          # rs1=x20
    addi  x0,  x21, 0          # rs1=x21
    addi  x0,  x22, 0          # rs1=x22
    addi  x0,  x23, 0          # rs1=x23
    addi  x0,  x24, 0          # rs1=x24
    addi  x0,  x25, 0          # rs1=x25
    addi  x0,  x26, 0          # rs1=x26
    addi  x0,  x27, 0          # rs1=x27
    addi  x0,  x28, 0          # rs1=x28
    addi  x0,  x29, 0          # rs1=x29
    addi  x0,  x31, 0          # rs1=x31
    nop
    nop
    nop
