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
    
    /* rtl/common/programs/test_rv32i.S
       A small RV32I program exercising many instruction classes.
       Save this file, then later assemble with an RV32 toolchain to produce prog1.hex.
       Each line has a comment describing the instruction.
    */

    .section .text
    .globl _start
_start:
    # Basic immediate/reg ops
    addi x1, x0, 5        # x1 = 5
    addi x2, x0, 7        # x2 = 7
    add  x3, x1, x2       # x3 = x1 + x2 = 12
    addi x4, x3, 1        # x4 = x3 + 1 = 13
    sub  x5, x3, x1       # x5 = x3 - x1 = 7

    # Logical
    and  x6, x3, x2       # x6 = x3 & x2
    or   x7, x3, x2       # x7 = x3 | x2
    xor  x8, x3, x2       # x8 = x3 ^ x2

    # Shift & compares
    sll  x9,  x3, x1      # x9 = x3 << (x1 & 0x1f)
    srl  x10, x3, x1      # x10 = x3 >> (x1 & 0x1f) logical
    sra  x11, x3, x1      # x11 = x3 >> (x1 & 0x1f) arithmetic
    slt  x12, x1, x2      # x12 = (x1 < x2) ? 1 : 0 (signed)
    sltu x13, x1, x2      # x13 = (x1 < x2) ? 1 : 0 (unsigned)

    # Immediate logical/shift
    andi x14, x3, 3       # x14 = x3 & 3
    ori  x15, x3, 4       # x15 = x3 | 4
    xori x16, x3, 5       # x16 = x3 ^ 5
    slli x17, x3, 1       # x17 = x3 << 1
    srli x18, x3, 1       # x18 = x3 >> 1 (logical)
    srai x19, x3, 1       # x19 = x3 >> 1 (arith)

    # Memory (store/load) — uses x1 as address base (x1=5) so choose safe address
    # Note: in a real test you’d set x1 to a proper aligned address; this is illustrative.
    addi x30, x0, 64      # x30 = 64  (use x30 as data base)
    sw   x3, 0(x30)       # store x3 -> mem[64]
    lw   x20, 0(x30)      # x20 = mem[64] (should get x3)

    # Branch examples
    beq  x1, x2, 1f       # if x1 == x2 goto label 1
    bne  x1, x2, 2f       # if x1 != x2 goto label 2
1:
    nop
2:
    nop

    # Jumps
    jal  x0, 4            # jump forward 4 bytes (illustration)
    # NOTE: Using jalr/jal requires careful PC offsets; treat as encoding example
    jalr x0, 0(x30)       # return-like jump to x30

    # U-type (LUI/AUIPC)
    lui  x21, 0x12345     # x21 = 0x12345 << 12
    auipc x22, 0x1        # x22 = pc + (0x1 << 12)

    # end with several nops
    nop
    nop