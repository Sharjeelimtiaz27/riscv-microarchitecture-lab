/*
===============================================================================
Project      : riscv-microarchitecture-lab
Author       : Sharjeel Imtiaz
Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
Year         : 2026
Version      : v1.0 (Week 04 -- SVA Assertions + Security)

Contact      : sharjeel.imtiaz@taltech.ee
               sharjeelimtiazprof@gmail.com

Description  :
SVA assertion module for the register file (regfile.sv).
Includes functional correctness properties AND security properties.

SECURITY THREAT MODEL
---------------------
x0 corruption:
  x0 must always be zero. Any write to rd=x0 must be silently discarded.
  Proof requires observing the internal regs[0] array element directly,
  not just the read mux output (a Trojan can store a value internally
  while the mux still returns 0).

Phantom write:
  regs[i] must change ONLY when we=1 AND rd=i. If the register changes
  without those conditions, a side-path exists -- phantom write Trojan.

Write isolation:
  Writing to register X must not alter register Y for any X != Y. An
  address decoder bug or glitch attack could corrupt multiple registers
  on a single write.

Temporal isolation:
  The register file uses synchronous write, asynchronous read. A write
  in cycle N is NOT visible on rd1/rd2 until cycle N+1. This is the
  write-before-read barrier. Breaking it enables forwarding-path attacks.

Reset integrity:
  After reset deasserts, all registers including the internal array
  must contain exactly zero. Surviving non-zero values can leak data
  across security context switches.

Internal signal access:
  regs[0], regs[1], regs[2] are exposed as explicit bind connections.
  The bind uses .* for the 9 standard ports and explicit overrides for
  the 3 internal array connections.

Bound to    : regfile (bottom of this file, module-level bind)
Run with    : formal/prove_single_cycle.tcl
===============================================================================
*/

// rtl/assertions/regfile_assertions.sv
`timescale 1ns/1ps

module regfile_assertions (
    // ALL ports are input -- assertion module observes only, never drives
    input logic        clk,
    input logic        rst_n,
    input logic        we,
    input logic [4:0]  rs1,
    input logic [4:0]  rs2,
    input logic [4:0]  rd,
    input logic [31:0] wd,
    input logic [31:0] rd1,
    input logic [31:0] rd2,
    // Internal array elements exposed via explicit bind connections
    input logic [31:0] regs_x0,  // regs[0] -- must always be 0
    input logic [31:0] regs_x1,  // regs[1] -- used in isolation proofs
    input logic [31:0] regs_x2   // regs[2] -- used in isolation proofs
);

    //=========================================================================
    // FUNCTIONAL PROPERTIES
    //=========================================================================

    // x0 read port 1: always returns zero (combinational read mux gates on rs1==0)
    property p_x0_rd1_zero;
        @(posedge clk) disable iff (!rst_n)
        (rs1 == 5'd0) |-> (rd1 == 32'd0);
    endproperty
    assert property (p_x0_rd1_zero)
        else $error("REGFILE FAIL: rd1 non-zero when rs1=x0");

    // x0 read port 2: always returns zero
    property p_x0_rd2_zero;
        @(posedge clk) disable iff (!rst_n)
        (rs2 == 5'd0) |-> (rd2 == 32'd0);
    endproperty
    assert property (p_x0_rd2_zero)
        else $error("REGFILE FAIL: rd2 non-zero when rs2=x0");

    // Write-then-read coherence (port 1):
    // Synchronous write: write in cycle N, read result visible in cycle N+1.
    // If we=1 and rd=R with data D in cycle N, then in cycle N+1 reading
    // rs1=R must return D.
    property p_write_read_coherence_p1;
        @(posedge clk) disable iff (!rst_n)
        (we && rd != 5'd0) |=>
            ((rs1 == $past(rd,1)) |-> (rd1 == $past(wd,1)));
    endproperty
    assert property (p_write_read_coherence_p1)
        else $error("REGFILE FAIL: write-then-read mismatch on rd1");

    // Write-then-read coherence (port 2):
    property p_write_read_coherence_p2;
        @(posedge clk) disable iff (!rst_n)
        (we && rd != 5'd0) |=>
            ((rs2 == $past(rd,1)) |-> (rd2 == $past(wd,1)));
    endproperty
    assert property (p_write_read_coherence_p2)
        else $error("REGFILE FAIL: write-then-read mismatch on rd2");

    // Reset: first cycle after reset deasserts, read ports return 0
    property p_reset_clears_read_ports;
        @(posedge clk)
        $rose(rst_n) |-> (rd1 == 32'd0 && rd2 == 32'd0);
    endproperty
    assert property (p_reset_clears_read_ports)
        else $error("REGFILE FAIL: read port non-zero after reset");

    //=========================================================================
    // SECURITY PROPERTIES
    //=========================================================================

    // SEC-1: x0 internal register is physically zero at all times.
    // Proves regs[0] itself, not the read mux output. A Trojan could maintain
    // a non-zero internal value while the mux masks it.
    property p_sec_x0_internal_zero;
        @(posedge clk) disable iff (!rst_n)
        regs_x0 == 32'd0;
    endproperty
    assert property (p_sec_x0_internal_zero)
        else $error("SECURITY FAIL: regs[0] != 0 -- x0 internally corrupted! value=%h", regs_x0);

    // SEC-2: Write to rd=x0 has no effect on the physical storage.
    // Even with we=1, rd=0, wd=0xDEADBEEF, regs[0] must stay 0 next cycle.
    property p_sec_x0_write_discarded;
        @(posedge clk) disable iff (!rst_n)
        (we && rd == 5'd0) |=> (regs_x0 == 32'd0);
    endproperty
    assert property (p_sec_x0_write_discarded)
        else $error("SECURITY FAIL: write to x0 propagated to regs[0]");

    // SEC-3: Phantom write impossible for x1.
    // If the write-enable condition for x1 is NOT met (we=0 OR rd!=1),
    // regs[1] must be stable in the next cycle. Any change is a phantom write.
    property p_sec_no_phantom_write_x1;
        @(posedge clk) disable iff (!rst_n)
        (!(we && rd == 5'd1)) |=> $stable(regs_x1);
    endproperty
    assert property (p_sec_no_phantom_write_x1)
        else $error("SECURITY FAIL: regs[1] changed without valid write-enable -- phantom write!");

    // SEC-4: Phantom write impossible for x2.
    property p_sec_no_phantom_write_x2;
        @(posedge clk) disable iff (!rst_n)
        (!(we && rd == 5'd2)) |=> $stable(regs_x2);
    endproperty
    assert property (p_sec_no_phantom_write_x2)
        else $error("SECURITY FAIL: regs[2] changed without valid write-enable -- phantom write!");

    // SEC-5: Write isolation -- writing x1 must not alter x2.
    // After any write to rd=1 (with any write data), regs[2] must be unchanged.
    property p_sec_write_x1_isolates_x2;
        @(posedge clk) disable iff (!rst_n)
        (we && rd == 5'd1) |=> $stable(regs_x2);
    endproperty
    assert property (p_sec_write_x1_isolates_x2)
        else $error("SECURITY FAIL: write to x1 corrupted x2 -- write isolation violated!");

    // SEC-6: Write isolation -- writing x2 must not alter x1.
    property p_sec_write_x2_isolates_x1;
        @(posedge clk) disable iff (!rst_n)
        (we && rd == 5'd2) |=> $stable(regs_x1);
    endproperty
    assert property (p_sec_write_x2_isolates_x1)
        else $error("SECURITY FAIL: write to x2 corrupted x1 -- write isolation violated!");

    // SEC-7: Write gate completeness for x1.
    // regs[1] is permitted to change ONLY when we=1 AND rd=1. This is the
    // formal proof that write_enable is the sole and complete write gate.
    // (SEC-3 and SEC-7 are equivalent but named separately for clarity.)
    property p_sec_write_gate_x1;
        @(posedge clk) disable iff (!rst_n)
        (!(we && rd == 5'd1)) |=> $stable(regs_x1);
    endproperty
    assert property (p_sec_write_gate_x1)
        else $error("SECURITY FAIL: regs[1] changed via path outside write-enable gate");

    // SEC-8: Write gate completeness for x2.
    property p_sec_write_gate_x2;
        @(posedge clk) disable iff (!rst_n)
        (!(we && rd == 5'd2)) |=> $stable(regs_x2);
    endproperty
    assert property (p_sec_write_gate_x2)
        else $error("SECURITY FAIL: regs[2] changed via path outside write-enable gate");

    // SEC-9: Reset integrity for x0 (internal array element).
    property p_sec_reset_clears_x0;
        @(posedge clk)
        $rose(rst_n) |-> (regs_x0 == 32'd0);
    endproperty
    assert property (p_sec_reset_clears_x0)
        else $error("SECURITY FAIL: regs[0] non-zero after reset");

    // SEC-10: Reset integrity for x1.
    property p_sec_reset_clears_x1;
        @(posedge clk)
        $rose(rst_n) |-> (regs_x1 == 32'd0);
    endproperty
    assert property (p_sec_reset_clears_x1)
        else $error("SECURITY FAIL: regs[1] non-zero after reset");

    // SEC-11: Reset integrity for x2.
    property p_sec_reset_clears_x2;
        @(posedge clk)
        $rose(rst_n) |-> (regs_x2 == 32'd0);
    endproperty
    assert property (p_sec_reset_clears_x2)
        else $error("SECURITY FAIL: regs[2] non-zero after reset");

    //=========================================================================
    // COVER POINTS
    //=========================================================================

    cover property (@(posedge clk) disable iff (!rst_n) (we && rd != 5'd0));
    cover property (@(posedge clk) disable iff (!rst_n) (we && rd == 5'd0));        // x0 write attempt
    cover property (@(posedge clk) disable iff (!rst_n) (rs1 == 5'd0));             // read x0
    cover property (@(posedge clk) disable iff (!rst_n) (we && rd == rs1));         // RAW same register
    cover property (@(posedge clk) disable iff (!rst_n)                             // write isolation scenario
        (we && rd == 5'd1) ##1 (rs1 == 5'd2));

endmodule

// =============================================================================
// BIND
// Bound at the regfile module level. All 9 standard ports match by name
// using .*  The three internal array connections override the .* for the
// regs_x0/x1/x2 ports which have no matching named signal in regfile scope.
// =============================================================================
bind regfile regfile_assertions u_regfile_assert (
    .*,
    .regs_x0 (regs[0]),
    .regs_x1 (regs[1]),
    .regs_x2 (regs[2])
);
