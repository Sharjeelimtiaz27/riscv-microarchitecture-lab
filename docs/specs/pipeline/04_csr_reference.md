# Pipelined RV64IM -- CSR Reference

**Document:** CSR Reference
**Version:** 0.1
**Applies to:** Planned pipeline processor, Machine mode (M-mode)

---

## Overview

The CSR (Control and Status Register) file provides machine-mode control, trap handling, and performance monitoring. The pipeline processor implements M-mode CSRs as defined in the RISC-V Privileged Architecture Specification v1.12.

---

## Required M-mode CSRs

### Machine Information Registers (read-only)

| Address | Name | Description |
|---|---|---|
| 0xF11 | mvendorid | Vendor ID (0 = non-commercial) |
| 0xF12 | marchid | Architecture ID |
| 0xF13 | mimpid | Implementation ID |
| 0xF14 | mhartid | Hardware thread ID (0 for single hart) |

### Machine Trap Setup

| Address | Name | Description |
|---|---|---|
| 0x300 | mstatus | Machine status register |
| 0x301 | misa | ISA and extensions |
| 0x304 | mie | Machine interrupt enable |
| 0x305 | mtvec | Machine trap-handler base address |

### Machine Trap Handling

| Address | Name | Description |
|---|---|---|
| 0x340 | mscratch | Scratch register for trap handlers |
| 0x341 | mepc | Machine exception program counter |
| 0x342 | mcause | Machine trap cause |
| 0x343 | mtval | Machine bad address or instruction |
| 0x344 | mip | Machine interrupt pending |

### Machine Counter/Timers

| Address | Name | Description |
|---|---|---|
| 0xB00 | mcycle | Cycle counter |
| 0xB02 | minstret | Instructions retired counter |

---

## mstatus Register

64-bit register. Key fields for M-mode:

| Bits | Field | Description |
|---|---|---|
| 3 | MIE | Machine interrupt enable |
| 7 | MPIE | Previous MIE value (saved on trap) |
| 12:11 | MPP | Previous privilege mode (M=11, S=01, U=00) |

---

## mtvec Register

| Bits | Field | Description |
|---|---|---|
| 63:2 | BASE | Trap handler base address (4-byte aligned) |
| 1:0 | MODE | 0 = Direct (all traps to BASE), 1 = Vectored |

---

## mcause Register

| Bit 63 | Bits 62:0 | Description |
|---|---|---|
| 1 | code | Interrupt, code is interrupt number |
| 0 | code | Exception, code is exception number |

### Exception Codes

| Code | Description |
|---|---|
| 0 | Instruction address misaligned |
| 1 | Instruction access fault |
| 2 | Illegal instruction |
| 3 | Breakpoint |
| 4 | Load address misaligned |
| 5 | Load access fault |
| 6 | Store/AMO address misaligned |
| 7 | Store/AMO access fault |
| 8 | Environment call from U-mode |
| 11 | Environment call from M-mode |

---

## Trap Entry and Exit

### On Trap (hardware action)

1. `mepc` = PC of trapping instruction
2. `mcause` = exception or interrupt code
3. `mtval` = faulting address or instruction (where applicable)
4. `mstatus.MPIE` = `mstatus.MIE`
5. `mstatus.MIE` = 0 (disable interrupts)
6. `mstatus.MPP` = current privilege mode
7. PC = `mtvec.BASE` (or `mtvec.BASE + 4 * cause` in vectored mode)

### On MRET (return from trap)

1. PC = `mepc`
2. `mstatus.MIE` = `mstatus.MPIE`
3. Privilege mode = `mstatus.MPP`
4. `mstatus.MPIE` = 1
5. `mstatus.MPP` = U-mode (or M if U not supported)

---

## CSR Access Rules

- All CSRs are accessed via the Zicsr instructions (CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI)
- Attempting to write a read-only CSR raises an illegal instruction exception
- Accessing a CSR that does not exist raises an illegal instruction exception
- CSR reads are non-destructive unless the instruction specifies a write (rd != x0 for read, rs1 != x0 for write)
