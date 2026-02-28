1️⃣ Local Machine (VS Code)

After writing RTL and testbench:

git add .
git commit -m "week-01: single-cycle RV32I + testbench + waveform"
git push
2️⃣ Login to University Server
ssh sharjeel@<server_address>
cd ~/sharjeelphd/Research/riscv-microarchitecture-lab
git pull
3️⃣ Load Cadence Environment

On TalTech server:

cad

Select:

1.3  (Cadence 2025 EDA version)

Confirm tools:

which xrun
xrun -version

Expected output example:

/eda/cadence/.../xrun
TOOL: xrun(64) 24.03-s004
4️⃣ Clean Previous Simulation Data
rm -rf work xcelium.d artifacts/*
mkdir -p artifacts
chmod u+rwx artifacts
5️⃣ Compile & Elaborate RTL + Testbench
xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/*.sv -l artifacts/xrun_elab.log

Check for errors:

tail -n 200 artifacts/xrun_elab.log

If no errors → proceed.

6️⃣ Run Simulation
xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/*.sv -R -access +rwc -l artifacts/xrun_run.log

Expected console output:

SMOKE PASS: program executed correctly
7️⃣ Waveform Generation

Testbench includes:

$dumpfile("waves.vcd");
$dumpvars(0, dut);

Generated file:

waves.vcd

Verify:

ls -l waves.vcd
8️⃣ View Waveform

On server (if GUI available):

gtkwave waves.vcd &

Or copy to local machine:

scp sharjeel@server:/path/to/riscv-microarchitecture-lab/waves.vcd .
gtkwave waves.vcd
9️⃣ Signals to Inspect in GTKWave

Add these signals:

dut.pc

dut.instr

dut.alu_res

dut.wb_data

dut.rf.regs[1]

dut.rf.regs[2]

dut.rf.regs[3]

🔟 Expected Register State

Program executed:

ADDI x1, x0, 5
ADDI x2, x0, 7
ADD  x3, x1, x2

Expected:

x1 = 5
x2 = 7
x3 = 12
SMOKE PASS
1️⃣1️⃣ Online Assembly (Temporary Solution)

To generate hex instructions:

Use:

https://riscvasm.lucasteske.dev/

Steps:

Paste assembly

Select RV32I

Copy machine code

Save into:

rtl/common/programs/prog1.hex

Each line must contain one 32-bit instruction (hex format).

1️⃣2️⃣ Common Errors & Fixes
Unresolved instance error

Cause: Not compiling all RTL files
Fix:

xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/*.sv
Cadence tools not found

Cause: Environment not loaded
Fix:

cad
FSDB generation error

Fallback to VCD via $dumpfile in testbench.