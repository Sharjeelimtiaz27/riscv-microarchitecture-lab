# Single-Cycle RV32I -- Instruction Set Reference

**Document:** ISA Reference
**Version:** 1.0
**Applies to:** `single_cycle_top` v1.0

---

## Instruction Formats

RV32I defines six instruction encoding formats. All instructions are 32 bits wide and 4-byte aligned.

```
R-type:  [ funct7 | rs2 | rs1 | funct3 |    rd    | opcode ]
          31    25  24 20  19 15  14  12   11     7   6     0

I-type:  [    imm[11:0]   | rs1 | funct3 |    rd    | opcode ]
          31            20  19 15  14  12   11     7   6     0

S-type:  [ imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode ]
          31       25  24 20  19 15  14  12   11     7   6     0

B-type:  [ imm[12|10:5] | rs2 | rs1 | funct3 | imm[4:1|11] | opcode ]
          31          25  24 20  19 15  14  12   11        7   6     0

U-type:  [         imm[31:12]          |    rd    | opcode ]
          31                         12  11     7   6     0

J-type:  [    imm[20|10:1|11|19:12]   |    rd    | opcode ]
          31                        12  11     7   6     0
```

Bit 0 of all branch and jump immediates is always implicitly zero (2-byte aligned target minimum).

---

## Opcode Map

| opcode[6:0] | Format | Instruction Class |
|---|---|---|
| 0110011 | R | Register-register ALU |
| 0010011 | I | Register-immediate ALU |
| 0000011 | I | Load |
| 0100011 | S | Store |
| 1100011 | B | Branch |
| 1101111 | J | JAL |
| 1100111 | I | JALR |
| 0110111 | U | LUI |
| 0010111 | U | AUIPC |
| 1110011 | I | SYSTEM (not implemented) |
| 0001111 | I | FENCE (not implemented) |

---

## R-type Instructions

All R-type instructions: opcode = 0110011, funct7 = 0000000 unless noted.

| Instruction | funct7 | funct3 | Operation | ALU Op Code |
|---|---|---|---|---|
| ADD  rd, rs1, rs2 | 0000000 | 000 | rd = rs1 + rs2 | 4'd0 |
| SUB  rd, rs1, rs2 | 0100000 | 000 | rd = rs1 - rs2 | 4'd1 |
| AND  rd, rs1, rs2 | 0000000 | 111 | rd = rs1 & rs2 | 4'd2 |
| OR   rd, rs1, rs2 | 0000000 | 110 | rd = rs1 \| rs2 | 4'd3 |
| XOR  rd, rs1, rs2 | 0000000 | 100 | rd = rs1 ^ rs2 | 4'd4 |
| SLT  rd, rs1, rs2 | 0000000 | 010 | rd = (rs1 < rs2) ? 1 : 0 (signed) | 4'd5 |
| SLL  rd, rs1, rs2 | 0000000 | 001 | rd = rs1 << rs2[4:0] | 4'd6 |
| SRL  rd, rs1, rs2 | 0000000 | 101 | rd = rs1 >> rs2[4:0] (logical) | 4'd7 |
| SRA  rd, rs1, rs2 | 0100000 | 101 | rd = rs1 >> rs2[4:0] (arithmetic) | 4'd8 |
| SLTU rd, rs1, rs2 | 0000000 | 011 | rd = (rs1 < rs2) ? 1 : 0 (unsigned) | 4'd9 |

---

## I-type ALU Instructions

opcode = 0010011

| Instruction | funct3 | imm[11:5] | Operation |
|---|---|---|---|
| ADDI  rd, rs1, imm | 000 | - | rd = rs1 + sign_ext(imm) |
| ANDI  rd, rs1, imm | 111 | - | rd = rs1 & sign_ext(imm) |
| ORI   rd, rs1, imm | 110 | - | rd = rs1 \| sign_ext(imm) |
| XORI  rd, rs1, imm | 100 | - | rd = rs1 ^ sign_ext(imm) |
| SLTI  rd, rs1, imm | 010 | - | rd = (rs1 < sign_ext(imm)) ? 1 : 0 (signed) |
| SLTIU rd, rs1, imm | 011 | - | rd = (rs1 < sign_ext(imm)) ? 1 : 0 (unsigned) |
| SLLI  rd, rs1, shamt | 001 | 0000000 | rd = rs1 << shamt |
| SRLI  rd, rs1, shamt | 101 | 0000000 | rd = rs1 >> shamt (logical) |
| SRAI  rd, rs1, shamt | 101 | 0100000 | rd = rs1 >> shamt (arithmetic) |

shamt = imm[4:0], valid range 0-31.

---

## Load Instructions

opcode = 0000011, effective address = rs1 + sign_ext(imm)

| Instruction | funct3 | Operation |
|---|---|---|
| LW rd, imm(rs1) | 010 | rd = mem[rs1 + imm] (32-bit word) |

Note: LB, LH, LBU, LHU are defined in RV32I but not implemented in this design. The data memory interface supports word-width access only.

---

## Store Instructions

opcode = 0100011, effective address = rs1 + sign_ext(imm)

| Instruction | funct3 | Operation |
|---|---|---|
| SW rs2, imm(rs1) | 010 | mem[rs1 + imm] = rs2 (32-bit word) |

Note: SB and SH are not implemented.

---

## Branch Instructions

opcode = 1100011, target = PC + sign_ext(imm), imm is 13-bit (bit 0 = 0)

| Instruction | funct3 | Condition |
|---|---|---|
| BEQ  rs1, rs2, imm | 000 | rs1 == rs2 |
| BNE  rs1, rs2, imm | 001 | rs1 != rs2 |
| BLT  rs1, rs2, imm | 100 | rs1 < rs2 (signed) |
| BGE  rs1, rs2, imm | 101 | rs1 >= rs2 (signed) |
| BLTU rs1, rs2, imm | 110 | rs1 < rs2 (unsigned) |
| BGEU rs1, rs2, imm | 111 | rs1 >= rs2 (unsigned) |

---

## Jump Instructions

| Instruction | opcode | Operation |
|---|---|---|
| JAL  rd, imm | 1101111 | rd = PC+4; PC = PC + sign_ext(imm) |
| JALR rd, imm(rs1) | 1100111 | rd = PC+4; PC = (rs1 + sign_ext(imm)) & ~1 |

JAL immediate is 21-bit (bit 0 = 0), encoded in J-type format.
JALR uses I-type format with funct3 = 000.

---

## Upper Immediate Instructions

| Instruction | opcode | Operation |
|---|---|---|
| LUI   rd, imm | 0110111 | rd = imm << 12 (upper 20 bits) |
| AUIPC rd, imm | 0010111 | rd = PC + (imm << 12) |

---

## Register File

| Register | ABI Name | Description |
|---|---|---|
| x0 | zero | Hardwired to 0; writes are discarded |
| x1 | ra | Return address (by convention) |
| x2 | sp | Stack pointer (by convention) |
| x3 | gp | Global pointer (by convention) |
| x4 | tp | Thread pointer (by convention) |
| x5-x7 | t0-t2 | Temporaries |
| x8 | s0/fp | Saved register / frame pointer |
| x9 | s1 | Saved register |
| x10-x11 | a0-a1 | Function arguments / return values |
| x12-x17 | a2-a7 | Function arguments |
| x18-x27 | s2-s11 | Saved registers |
| x28-x31 | t3-t6 | Temporaries |

---

## Instruction Encoding Examples

| Assembly | Hex Encoding | Derivation |
|---|---|---|
| addi x1, x0, 5 | 0x00500093 | imm=5, rs1=0, funct3=000, rd=1, op=0010011 |
| add  x3, x1, x2 | 0x002081B3 | funct7=0, rs2=2, rs1=1, funct3=000, rd=3, op=0110011 |
| sw   x3, 0(x30) | 0x003F2023 | imm=0, rs2=3, rs1=30, funct3=010, op=0100011 |
| lw   x22, 0(x30) | 0x000F2B03 | imm=0, rs1=30, funct3=010, rd=22, op=0000011 |
| slti x20, x1, 10 | 0x00A0AA13 | imm=10, rs1=1, funct3=010, rd=20, op=0010011 |
| jal  x0, +12 | 0x00C0006F | imm=12, rd=0, op=1101111 |
| beq  x1, x2, +8 | 0x00208463 | imm=8, rs2=2, rs1=1, funct3=000, op=1100011 |
