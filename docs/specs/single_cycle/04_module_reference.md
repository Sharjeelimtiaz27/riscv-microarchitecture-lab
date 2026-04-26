# Single-Cycle RV32I -- RTL Module Reference

**Document:** Module Reference
**Version:** 1.0
**Applies to:** `single_cycle_top` v1.0

All modules are written in SystemVerilog 2012. All sequential logic uses `always_ff`. All combinational logic uses `always_comb`. Active-low reset is named `rst_n` throughout.

---

## single_cycle_top

**File:** `rtl/single_cycle/single_cycle_top.sv`

Top-level module that instantiates and connects all sub-modules.

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `IMEM_INIT_FILE` | `""` | Path to hex file for instruction memory initialisation |

### Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | System clock |
| `rst_n` | input | 1 | Active-low synchronous reset |

### Internal Signals

| Signal | Width | Description |
|---|---|---|
| `pc_out` | 32 | Current program counter value |
| `pc_next` | 32 | Next PC value (combinational) |
| `instr` | 32 | Instruction word from IMEM |
| `rs1_data` | 32 | Register file read port 1 data |
| `rs2_data` | 32 | Register file read port 2 data |
| `rd_data` | 32 | Write-back data to register file |
| `imm_ext` | 32 | Sign-extended immediate |
| `alu_out` | 32 | ALU result |
| `alu_zero` | 1 | ALU zero flag |
| `mem_rdata` | 32 | Data memory read data |
| `alu_ctrl_out` | 4 | ALU operation select |

---

## pc

**File:** `rtl/common/pc.sv`

32-bit program counter register with synchronous active-low reset.

### Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | System clock |
| `rst_n` | input | 1 | Active-low synchronous reset |
| `pc_next` | input | 32 | Next PC value |
| `pc_out` | output | 32 | Current PC value |

### Behaviour

On reset: `pc_out = 0`
On rising clock edge: `pc_out <= pc_next`

---

## regfile

**File:** `rtl/common/regfile.sv`

32-entry, 32-bit register file. Register x0 is hardwired to zero. Two asynchronous read ports, one synchronous write port.

### Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | System clock |
| `rst_n` | input | 1 | Active-low reset (not used for register reset) |
| `reg_write` | input | 1 | Write enable |
| `rs1` | input | 5 | Read address port 1 |
| `rs2` | input | 5 | Read address port 2 |
| `rd` | input | 5 | Write address |
| `rd_data` | input | 32 | Write data |
| `rs1_data` | output | 32 | Read data port 1 |
| `rs2_data` | output | 32 | Read data port 2 |

### Behaviour

- Read ports are asynchronous (combinational): `rs1_data = regs[rs1]`
- Write port is synchronous: on rising clock edge, if `reg_write && rd != 0`, then `regs[rd] <= rd_data`
- `regs[0]` is never written; reads always return 0

### Storage Declaration

```systemverilog
logic [31:0] regs [32];
```

---

## alu

**File:** `rtl/common/alu.sv`

32-bit combinational ALU supporting ten operations.

### Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `a` | input | 32 | First operand |
| `b` | input | 32 | Second operand |
| `alu_ctrl` | input | 4 | Operation select |
| `result` | output | 32 | ALU result |
| `zero` | output | 1 | High when result == 0 |

### Operation Table

| alu_ctrl | Operation | Expression |
|---|---|---|
| 4'd0 | ADD | a + b |
| 4'd1 | SUB | a - b |
| 4'd2 | AND | a & b |
| 4'd3 | OR | a \| b |
| 4'd4 | XOR | a ^ b |
| 4'd5 | SLT | ($signed(a) < $signed(b)) ? 1 : 0 |
| 4'd6 | SLL | a << b[4:0] |
| 4'd7 | SRL | a >> b[4:0] |
| 4'd8 | SRA | $signed(a) >>> b[4:0] |
| 4'd9 | SLTU | (a < b) ? 1 : 0 |
| default | -- | 32'hDEAD_BEEF |

---

## alu_ctrl

**File:** `rtl/common/alu_ctrl.sv`

Combinational decoder that maps `alu_op`, `funct3`, and `funct7[5]` to the 4-bit ALU control code.

### Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `alu_op` | input | 2 | Operation class from control unit |
| `funct3` | input | 3 | Instruction funct3 field |
| `funct7_5` | input | 1 | Instruction funct7 bit 5 |
| `alu_ctrl_out` | output | 4 | ALU operation select |

### Decoding Priority

1. If `alu_op == 2'b00`: always ADD (for memory address computation)
2. If `alu_op == 2'b01`: always SUB (for branch comparison)
3. If `alu_op == 2'b10`: decode from funct3 and funct7_5 (R-type and I-type ALU)

---

## immgen

**File:** `rtl/common/immgen.sv`

Combinational immediate generator. Decodes the instruction format from the opcode and assembles the correct 32-bit sign-extended immediate.

### Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `instr` | input | 32 | Full 32-bit instruction word |
| `imm_ext` | output | 32 | Sign-extended immediate value |

### Format Detection

Format is selected by `instr[6:0]` (opcode). See `03_microarchitecture.md` for the bit-field extraction for each format.

---

## inst_memory

**File:** `rtl/common/inst_memory.sv`

Synchronous instruction memory. Initialised at simulation start from a hex file.

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `INIT_FILE` | `""` | Path to `$readmemh` hex file |

### Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | System clock (used for `$readmemh` timing only) |
| `addr` | input | 32 | Byte address |
| `instr` | output | 32 | Instruction word |

### Behaviour

- Storage: `logic [31:0] mem [0:255]` (256 words, 1 KB)
- Read: `instr = mem[addr[9:2]]` (word-aligned, combinational)
- Initialisation: `$readmemh(INIT_FILE, mem)` in an `initial` block
- Uninitialized entries default to 0

---

## data_memory

**File:** `rtl/common/data_memory.sv`

Word-addressed data memory with synchronous write and combinational read.

### Ports

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | System clock |
| `rst_n` | input | 1 | Active-low reset (initialises memory to 0) |
| `wr_en` | input | 1 | Write enable |
| `rd_en` | input | 1 | Read enable |
| `addr` | input | 32 | Byte address |
| `wdata` | input | 32 | Write data |
| `rdata` | output | 32 | Read data |

### Behaviour

- Storage: `logic [31:0] mem [0:255]` (256 words, 1 KB)
- Write: synchronous on rising clock edge when `wr_en` is asserted
- Read: `rdata = rd_en ? mem[addr[9:2]] : 32'd0` (combinational)
- Address: word-aligned via `addr[9:2]`
