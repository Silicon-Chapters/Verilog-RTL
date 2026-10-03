`timescale 1ns/1ps

module logic_gates_tb;

    // Stimulus is driven procedurally -> reg. DUT outputs are observed -> wire.
    reg  a, b;
    wire y_and, y_or, y_not_a, y_nand, y_nor, y_xor, y_xnor;

    // Bookkeeping.
    integer tests  = 0;
    integer checks = 0;
    integer errors = 0;

    // Recomputed expected values (one per output).
    reg exp_and, exp_or, exp_not_a, exp_nand, exp_nor, exp_xor, exp_xnor;

    // Device under test.
    logic_gates dut (
        .a(a), .b(b),
        .y_and(y_and), .y_or(y_or), .y_not_a(y_not_a),
        .y_nand(y_nand), .y_nor(y_nor), .y_xor(y_xor), .y_xnor(y_xnor)
    );

    // One self-checking comparison. Case-equality (===) treats x/z as real
    // mismatches instead of silently accepting them.
    task check;
        input [8*8-1:0] name;   // up to 8-character signal name
        input actual;
        input expected;
        begin
            checks = checks + 1;
            if (actual === expected) begin
                $display("    PASS  %-8s = %b", name, actual);
            end else begin
                errors = errors + 1;
                $display("    FAIL  %-8s = %b  (expected %b)", name, actual, expected);
            end
        end
    endtask

    // Apply one vector, compute expected, let logic settle, then check outputs.
    task apply_and_check;
        input aa, bb;
        begin
            a = aa; b = bb;
            #1;                 // settle before sampling (avoids race on checks)
            tests = tests + 1;
            exp_and   =  (aa & bb);
            exp_or    =  (aa | bb);
            exp_not_a = ~(aa);
            exp_nand  = ~(aa & bb);
            exp_nor   = ~(aa | bb);
            exp_xor   =  (aa ^ bb);
            exp_xnor  = ~(aa ^ bb);
            $display("[T%0d] a=%b b=%b", tests, a, b);
            check("y_and",   y_and,   exp_and);
            check("y_or",    y_or,    exp_or);
            check("y_not_a", y_not_a, exp_not_a);
            check("y_nand",  y_nand,  exp_nand);
            check("y_nor",   y_nor,   exp_nor);
            check("y_xor",   y_xor,   exp_xor);
            check("y_xnor",  y_xnor,  exp_xnor);
        end
    endtask

    initial begin
        $dumpfile("basic_logic_gates.vcd");
        $dumpvars(0, logic_gates_tb);

        $display("=== Self-checking testbench ===");

        // The four normal binary tests (the real truth-table verification).
        apply_and_check(1'b0, 1'b0);
        apply_and_check(1'b0, 1'b1);
        apply_and_check(1'b1, 1'b0);
        apply_and_check(1'b1, 1'b1);

        $display("----------------------------------------------------------");
        $display("Tests run : %0d", tests);
        $display("Checks run: %0d", checks);
        $display("Errors    : %0d", errors);
        if (errors == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: TEST FAILED");
        $display("==========================================================");

        // ---- Optional four-state exploration (NOT one of the 4 binary tests) ----
        // Shows how gate primitives propagate x (unknown) and z (high-Z). These
        // lines are informational only and are never counted as pass/fail checks.
        $display("");
        $display("--- Optional X/Z exploration (not scored) ---");
        a = 1'bx; b = 1'b1;
        #1 $display("a=x b=1 -> y_and=%b y_or=%b y_xor=%b y_nand=%b",
                    y_and, y_or, y_xor, y_nand);
        a = 1'bz; b = 1'b0;
        #1 $display("a=z b=0 -> y_and=%b y_or=%b y_xor=%b y_nand=%b",
                    y_and, y_or, y_xor, y_nand);
        $display("Note: a controlling value forces a known output (and with 0 -> 0,");
        $display("or with 1 -> 1); otherwise x/z propagates as x.");

        $finish;
    end

endmodule
