# Single-Cycle RV32I -- Microarchitecture

**Document:** Microarchitecture Reference
**Version:** 1.0
**Applies to:** `single_cycle_top` v1.0

---

## Design Principle

The single-cycle implementation executes every instruction in exactly one clock cycle. All combinational logic -- instruction fetch, decode, execute, memory access, and write-back -- is resolved within a single clock period. The register file and program counter are the only sequential elements; they are updated on the rising clock edge.

This approach maximises simplicity and is the correct starting point for building intuition about datapath design before pipelining is introduced.

---

## Datapath

```
                             +--------+
              +-- pc_out --> | INST   | --> instr[31:0]
              |              | MEMORY |
   +------+   |              +--------+
   |  PC  |---+
   |      |<--+------ pc_next (mux output)
   +------+   |
              |    +-------------------+
              |    |   CONTROL UNIT    |
              |    |  (combinational)  |
              |    |                   |
              |    | opcode --> ctrl:  |
              |    |   reg_write       |
              |    |   alu_src         |
              |    |   mem_write       |
              |    |   mem_read        |
              |    |   branch          |
              |    |   jump            |
              |    |   result_src      |
              |    +-------------------+
              |
              |    +-------------------+     +---------+
              |    |   REGISTER FILE   |     |  IMM    |
              |    |                   |     |  GEN    |
              |    | rs1 --> rs1_data  |     |         |
              |    | rs2 --> rs2_data  |     | imm_ext |
              |    | rd  <-- rd_data   |     +---------+
              |    +-------------------+
              |           |    |              |
              |        rs1_data  rs2_data     |
              |           |    |              |
              |           v    v (or imm_ext, via alu_src mux)
              |         +----------+
              |         |   ALU    |
              |         |          |
              |         | alu_out  |
              |         | zero     |
              |         +----+-----+
              |              |
              |      +-------+-------+
              |      |               |
              |  alu_out         +--------+
              |      |           |  DATA  |
              |      |           | MEMORY |
              |      |           |        |
              |      |           | rdata  |
              |      |           +--------+
              |      |               |
              |      +-------+-------+
              |              |
              |      result_src mux (alu_out / mem_rdata / pc+4)
              |              |
              +-- pc_next <--+   (branch/jump logic)
                             |
                          rd_data --> register file write-back
```

---

## Control Signals

The control unit decodes `instr[6:0]` (opcode) and generates the following signals. All are combinational with zero pipeline registers.

| Signal | Width | Description |
|---|---|---|
| `reg_write` | 1 | Enable write-back to register file |
| `alu_src` | 1 | ALU second operand: 0 = rs2_data, 1 = imm_ext |
| `mem_write` | 1 | Enable data memory write |
| `mem_read` | 1 | Enable data memory read |
| `branch` | 1 | Instruction is a branch type |
| `jump` | 1 | Instruction is JAL or JALR |
| `result_src` | 2 | Write-back source: 00=ALU, 01=mem_rdata, 10=PC+4 |
| `alu_op` | 2 | ALU operation class sent to alu_ctrl |
| `pc_src` | 1 | PC source: 0 = PC+4, 1 = branch/jump target |

---

## Control Signal Truth Table

| Instruction Class | reg_write | alu_src | mem_write | mem_read | branch | jump | result_src | alu_op |
|---|---|---|---|---|---|---|---|---|
| R-type | 1 | 0 | 0 | 0 | 0 | 0 | 00 | 10 |
| I-type ALU | 1 | 1 | 0 | 0 | 0 | 0 | 00 | 10 |
| Load | 1 | 1 | 0 | 1 | 0 | 0 | 01 | 00 |
| Store | 0 | 1 | 1 | 0 | 0 | 0 | -- | 00 |
| Branch | 0 | 0 | 0 | 0 | 1 | 0 | -- | 01 |
| JAL | 1 | -- | 0 | 0 | 0 | 1 | 10 | -- |
| JALR | 1 | 1 | 0 | 0 | 0 | 1 | 10 | 00 |
| LUI | 1 | 1 | 0 | 0 | 0 | 0 | 00 | 11 |
| AUIPC | 1 | 1 | 0 | 0 | 0 | 0 | 00 | 11 |

alu_op encoding: 00 = ADD (for load/store address), 01 = SUB (for branch compare), 10 = decode from funct3/funct7, 11 = pass-through (for LUI/AUIPC).

---

## ALU Operation Decoder (alu_ctrl)

The `alu_ctrl` module decodes `alu_op`, `funct3`, and `funct7[5]` to produce the 4-bit `alu_ctrl_out` signal consumed by the ALU.

| alu_op | funct3 | funct7[5] | alu_ctrl_out | Operation |
|---|---|---|---|---|
| 00 | --- | --- | 0000 | ADD |
| 01 | --- | --- | 0001 | SUB |
| 10 | 000 | 0 | 0000 | ADD |
| 10 | 000 | 1 | 0001 | SUB |
| 10 | 111 | --- | 0010 | AND |
| 10 | 110 | --- | 0011 | OR |
| 10 | 100 | --- | 0100 | XOR |
| 10 | 010 | --- | 0101 | SLT |
| 10 | 001 | --- | 0110 | SLL |
| 10 | 101 | 0 | 0111 | SRL |
| 10 | 101 | 1 | 1000 | SRA |
| 10 | 011 | --- | 1001 | SLTU |

---

## Immediate Generator (immgen)

The `immgen` module sign-extends the instruction immediate field based on the instruction format detected from the opcode.

| Format | Opcode | imm_ext Construction |
|---|---|---|
| I-type | 0010011, 0000011, 1100111 | sign_ext(instr[31:20]) |
| S-type | 0100011 | sign_ext({instr[31:25], instr[11:7]}) |
| B-type | 1100011 | sign_ext({instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}) |
| U-type | 0110111, 0010111 | {instr[31:12], 12'b0} |
| J-type | 1101111 | sign_ext({instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}) |

---

## Program Counter Logic

PC update logic (combinational):

```
branch_taken = branch & (alu_zero ^ invert_flag)
pc_target    = PC + imm_ext          (branch or JAL)
jalr_target  = (rs1_data + imm_ext) & ~32'h1
pc_next      = jump    ? (jalr ? jalr_target : pc_target)
             : branch_taken ? pc_target
             : PC + 4
```

The PC register updates on the rising clock edge when rst_n is asserted.

---

## Critical Path

In the single-cycle implementation the critical timing path runs through:

```
IMEM read --> decode --> register file read --> ALU --> DMEM read --> write-back mux
```

This path determines the minimum achievable clock period. In a typical 65 nm standard cell library this path limits the clock to approximately 200-400 MHz depending on memory access time. The pipelined design breaks this path into five shorter stages.

---

## Reset Behaviour

On deassertion of rst_n:

- PC is set to 0x00000000
- Register file values are not reset (undefined until written)
- Data memory is not reset (initialized to zero in simulation)
- All control signals are combinatorially determined from the zero-address instruction (which the IMEM returns as zero = NOP-like behaviour)
