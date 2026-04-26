# Pipelined RV64IM -- Instruction Set Reference

**Document:** ISA Reference
**Version:** 0.1
**Applies to:** Planned pipeline processor

---

## RV64I Base -- Additions over RV32I

RV64I retains all RV32I instructions and adds the following:

### 64-bit Arithmetic

| Instruction | Operation |
|---|---|
| ADDIW rd, rs1, imm | rd = sign_ext(rs1[31:0] + imm)[63:0] |
| SLLIW rd, rs1, shamt | rd = sign_ext(rs1[31:0] << shamt) |
| SRLIW rd, rs1, shamt | rd = sign_ext(rs1[31:0] >> shamt logical) |
| SRAIW rd, rs1, shamt | rd = sign_ext($signed(rs1[31:0]) >>> shamt) |
| ADDW rd, rs1, rs2 | rd = sign_ext(rs1[31:0] + rs2[31:0]) |
| SUBW rd, rs1, rs2 | rd = sign_ext(rs1[31:0] - rs2[31:0]) |
| SLLW rd, rs1, rs2 | rd = sign_ext(rs1[31:0] << rs2[4:0]) |
| SRLW rd, rs1, rs2 | rd = sign_ext(rs1[31:0] >> rs2[4:0] logical) |
| SRAW rd, rs1, rs2 | rd = sign_ext($signed(rs1[31:0]) >>> rs2[4:0]) |

The W-suffix instructions operate on the lower 32 bits and sign-extend the result to 64 bits.

### 64-bit Loads and Stores

| Instruction | funct3 | Operation |
|---|---|---|
| LB rd, imm(rs1) | 000 | rd = sign_ext(mem[rs1+imm][7:0]) |
| LH rd, imm(rs1) | 001 | rd = sign_ext(mem[rs1+imm][15:0]) |
| LW rd, imm(rs1) | 010 | rd = sign_ext(mem[rs1+imm][31:0]) |
| LD rd, imm(rs1) | 011 | rd = mem[rs1+imm][63:0] |
| LBU rd, imm(rs1) | 100 | rd = zero_ext(mem[rs1+imm][7:0]) |
| LHU rd, imm(rs1) | 101 | rd = zero_ext(mem[rs1+imm][15:0]) |
| LWU rd, imm(rs1) | 110 | rd = zero_ext(mem[rs1+imm][31:0]) |
| SB rs2, imm(rs1) | 000 | mem[rs1+imm][7:0] = rs2[7:0] |
| SH rs2, imm(rs1) | 001 | mem[rs1+imm][15:0] = rs2[15:0] |
| SW rs2, imm(rs1) | 010 | mem[rs1+imm][31:0] = rs2[31:0] |
| SD rs2, imm(rs1) | 011 | mem[rs1+imm][63:0] = rs2[63:0] |

---

## M Extension -- Integer Multiply and Divide

### RV64M R-type Instructions

opcode = 0110011, funct7 = 0000001 for all M-extension instructions.

| Instruction | funct3 | Operation |
|---|---|---|
| MUL rd, rs1, rs2 | 000 | rd = (rs1 * rs2)[63:0] |
| MULH rd, rs1, rs2 | 001 | rd = ($signed(rs1) * $signed(rs2))[127:64] |
| MULHSU rd, rs1, rs2 | 010 | rd = ($signed(rs1) * $unsigned(rs2))[127:64] |
| MULHU rd, rs1, rs2 | 011 | rd = ($unsigned(rs1) * $unsigned(rs2))[127:64] |
| DIV rd, rs1, rs2 | 100 | rd = $signed(rs1) / $signed(rs2) |
| DIVU rd, rs1, rs2 | 101 | rd = $unsigned(rs1) / $unsigned(rs2) |
| REM rd, rs1, rs2 | 110 | rd = $signed(rs1) % $signed(rs2) |
| REMU rd, rs1, rs2 | 111 | rd = $unsigned(rs1) % $unsigned(rs2) |

### RV64M W-suffix (32-bit operands, sign-extended result)

opcode = 0111011, funct7 = 0000001

| Instruction | funct3 | Operation |
|---|---|---|
| MULW rd, rs1, rs2 | 000 | rd = sign_ext(rs1[31:0] * rs2[31:0]) |
| DIVW rd, rs1, rs2 | 100 | rd = sign_ext($signed(rs1[31:0]) / $signed(rs2[31:0])) |
| DIVUW rd, rs1, rs2 | 101 | rd = sign_ext($unsigned(rs1[31:0]) / $unsigned(rs2[31:0])) |
| REMW rd, rs1, rs2 | 110 | rd = sign_ext($signed(rs1[31:0]) % $signed(rs2[31:0])) |
| REMUW rd, rs1, rs2 | 111 | rd = sign_ext($unsigned(rs1[31:0]) % $unsigned(rs2[31:0])) |

### Corner Cases (required by specification)

| Condition | Result |
|---|---|
| Division by zero | DIV: -1, DIVU: 2^64-1, REM: rs1, REMU: rs1 |
| Overflow (signed, most negative / -1) | DIV: most negative integer, REM: 0 |

---

## CSR Instructions (Zicsr)

Required for machine-mode privilege support.

opcode = 1110011

| Instruction | funct3 | Operation |
|---|---|---|
| CSRRW rd, csr, rs1 | 001 | rd = CSR[csr]; CSR[csr] = rs1 |
| CSRRS rd, csr, rs1 | 010 | rd = CSR[csr]; CSR[csr] \|= rs1 |
| CSRRC rd, csr, rs1 | 011 | rd = CSR[csr]; CSR[csr] &= ~rs1 |
| CSRRWI rd, csr, imm | 101 | rd = CSR[csr]; CSR[csr] = zero_ext(imm[4:0]) |
| CSRRSI rd, csr, imm | 110 | rd = CSR[csr]; CSR[csr] \|= zero_ext(imm[4:0]) |
| CSRRCI rd, csr, imm | 111 | rd = CSR[csr]; CSR[csr] &= ~zero_ext(imm[4:0]) |

---

## Register File

32 general-purpose registers, each 64 bits wide. Same ABI naming as RV32I. x0 is hardwired to zero.

---

## Implementation Priority

| Group | Priority | Reason |
|---|---|---|
| RV64I integer | P1 | Core functionality |
| M multiply | P1 | Required for most software |
| M divide | P2 | Slower, multi-cycle unit |
| Zicsr | P2 | Required for trap handling |
| FENCE | P3 | Memory ordering for multi-core |
| A atomics | P4 | Required for OS |
| F/D FPU | P5 | Scientific computing |
