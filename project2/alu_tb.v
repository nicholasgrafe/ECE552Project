`timescale 1ns/1ps
`default_nettype none

module alu_tb;
    // Inputs
    reg [2:0] opsel;
    reg sub;
    reg unsigned_op;
    reg arith;
    reg [31:0] op1;
    reg [31:0] op2;
    
    // Outputs
    wire [31:0] result;
    wire eq;
    wire slt;
    
    // Instantiate the ALU
    alu dut (
        .i_opsel(opsel),
        .i_sub(sub),
        .i_unsigned(unsigned_op),
        .i_arith(arith),
        .i_op1(op1),
        .i_op2(op2),
        .o_result(result),
        .o_eq(eq),
        .o_slt(slt)
    );
    
    // Test variables
    integer test_num;
    integer errors;
    reg [31:0] expected;
    
    // Helper task for checking results
    task check_result;
        input [31:0] exp_result;
        input exp_eq;
        input exp_slt;
        input [200*8:1] test_name;
        begin
            if (result !== exp_result || eq !== exp_eq || slt !== exp_slt) begin
                $display("  FAIL: %0s", test_name);
                $display("    op1=0x%h, op2=0x%h", op1, op2);
                $display("    result=0x%h (expected 0x%h)", result, exp_result);
                $display("    eq=%b (expected %b), slt=%b (expected %b)", eq, exp_eq, slt, exp_slt);
                errors = errors + 1;
            end else begin
                $display("  PASS: %0s", test_name);
            end
        end
    endtask
    
    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);
        
        test_num = 0;
        errors = 0;
        
        $display("\n========================================");
        $display("ALU Testbench");
        $display("========================================\n");
        
        //==============================================
        // Test 1: Addition (opsel = 3'b000, sub = 0)
        //==============================================
        test_num = test_num + 1;
        $display("Test %0d: Addition", test_num);
        
        opsel = 3'b000;
        sub = 0;
        unsigned_op = 0;
        arith = 0;
        
        op1 = 32'd100;
        op2 = 32'd50;
        #1;
        check_result(32'd150, 0, 0, "100 + 50 = 150");
        
        op1 = 32'hFFFFFFFF;  // -1 in signed
        op2 = 32'd1;
        #1;
        check_result(32'd0, 0, 1, "0xFFFFFFFF + 1 = 0 (overflow)");
        
        op1 = 32'h80000000;  // Most negative number
        op2 = 32'h80000000;
        #1;
        check_result(32'd0, 1, 0, "0x80000000 + 0x80000000 = 0 (overflow)");
        
        //==============================================
        // Test 2: Subtraction (opsel = 3'b000, sub = 1)
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Subtraction", test_num);
        
        opsel = 3'b000;
        sub = 1;
        
        op1 = 32'd100;
        op2 = 32'd50;
        #1;
        check_result(32'd50, 0, 0, "100 - 50 = 50");
        
        op1 = 32'd50;
        op2 = 32'd100;
        #1;
        expected = -32'd50;
        check_result(expected, 0, 1, "50 - 100 = -50");
        
        op1 = 32'd0;
        op2 = 32'd1;
        #1;
        check_result(32'hFFFFFFFF, 0, 1, "0 - 1 = 0xFFFFFFFF");
        
        //==============================================
        // Test 3: Shift Left Logical (opsel = 3'b001)
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Shift Left Logical", test_num);
        
        opsel = 3'b001;
        sub = 0;
        
        op1 = 32'h00000001;
        op2 = 32'd0;
        #1;
        check_result(32'h00000001, 0, 0, "1 << 0 = 1");

        op1 = 32'h00000001;
        op2 = 32'd1;
        #1;
        check_result(32'h00000002, 1, 0, "1 << 1 = 2");
        
        op1 = 32'h00000001;
        op2 = 32'd4;
        #1;
        check_result(32'h00000010, 0, 1, "1 << 4 = 16");
        
        op1 = 32'h00000001;
        op2 = 32'd31;
        #1;
        check_result(32'h80000000, 0, 1, "1 << 31 = 0x80000000");
        
        op1 = 32'h12345678;
        op2 = 32'd8;
        #1;
        check_result(32'h34567800, 0, 0, "0x12345678 << 8");
        
        // Test that only lower 5 bits of shift amount are used
        op1 = 32'h00000001;
        op2 = 32'd33;  // Should be same as shift by 1 (33 % 32 = 1)
        #1;
        check_result(32'h00000002, 0, 1, "1 << 33 = 1 << 1 = 2");
        
        //==============================================
        // Test 4: Set Less Than Signed (opsel = 3'b010/011)
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Set Less Than (Signed)", test_num);
        
        opsel = 3'b010;
        unsigned_op = 0;
        
        op1 = 32'd10;
        op2 = 32'd20;
        #1;
        check_result(32'd1, 0, 1, "10 < 20 (signed) = 1");
        
        op1 = 32'd20;
        op2 = 32'd10;
        #1;
        check_result(32'd0, 0, 0, "20 < 10 (signed) = 0");
        
        op1 = 32'hFFFFFFFF;  // -1
        op2 = 32'd0;
        #1;
        check_result(32'd1, 0, 1, "-1 < 0 (signed) = 1");
        
        op1 = 32'd0;
        op2 = 32'hFFFFFFFF;  // -1
        #1;
        check_result(32'd0, 0, 0, "0 < -1 (signed) = 0");
        
        op1 = 32'h80000000;  // Most negative
        op2 = 32'h7FFFFFFF;  // Most positive
        #1;
        check_result(32'd1, 0, 1, "-2147483648 < 2147483647 (signed) = 1");
        
        // Test opsel = 3'b011 gives same result
        opsel = 3'b011;
        op1 = 32'd10;
        op2 = 32'd20;
        #1;
        check_result(32'd1, 0, 1, "10 < 20 (signed, opsel=011) = 1");
        
        //==============================================
        // Test 5: Set Less Than Unsigned (opsel = 3'b010/011)
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Set Less Than (Unsigned)", test_num);
        
        opsel = 3'b010;
        unsigned_op = 1;
        
        op1 = 32'd10;
        op2 = 32'd20;
        #1;
        check_result(32'd1, 0, 1, "10 < 20 (unsigned) = 1");
        
        op1 = 32'hFFFFFFFF;
        op2 = 32'd0;
        #1;
        check_result(32'd0, 0, 0, "0xFFFFFFFF < 0 (unsigned) = 0");
        
        op1 = 32'd0;
        op2 = 32'hFFFFFFFF;
        #1;
        check_result(32'd1, 0, 1, "0 < 0xFFFFFFFF (unsigned) = 1");
        
        op1 = 32'h80000000;
        op2 = 32'h7FFFFFFF;
        #1;
        check_result(32'd0, 0, 0, "0x80000000 < 0x7FFFFFFF (unsigned) = 0");
        
        //==============================================
        // Test 6: XOR (opsel = 3'b100)
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: XOR", test_num);
        
        opsel = 3'b100;
        unsigned_op = 0;
        
        op1 = 32'hAAAAAAAA;
        op2 = 32'h55555555;
        #1;
        check_result(32'hFFFFFFFF, 0, 1, "0xAAAAAAAA ^ 0x55555555 = 0xFFFFFFFF");
        
        op1 = 32'hFFFFFFFF;
        op2 = 32'hFFFFFFFF;
        #1;
        check_result(32'h00000000, 1, 0, "0xFFFFFFFF ^ 0xFFFFFFFF = 0");
        
        op1 = 32'h12345678;
        op2 = 32'h00000000;
        #1;
        check_result(32'h12345678, 0, 0, "0x12345678 ^ 0 = 0x12345678");
        
        //==============================================
        // Test 7: Shift Right Logical (opsel = 3'b101, arith = 0)
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Shift Right Logical", test_num);
        
        opsel = 3'b101;
        arith = 0;
        
        op1 = 32'h80000000;
        op2 = 32'd0;
        #1;
        check_result(32'h80000000, 0, 1, "0x80000000 >> 0 = 0x80000000");
        
        op1 = 32'h80000000;
        op2 = 32'd1;
        #1;
        check_result(32'h40000000, 0, 1, "0x80000000 >> 1 = 0x40000000 (logical)");
        
        op1 = 32'h80000000;
        op2 = 32'd4;
        #1;
        check_result(32'h08000000, 0, 1, "0x80000000 >> 4 = 0x08000000 (logical)");
        
        op1 = 32'hFFFFFFFF;
        op2 = 32'd8;
        #1;
        check_result(32'h00FFFFFF, 0, 1, "0xFFFFFFFF >> 8 = 0x00FFFFFF (logical)");
        
        op1 = 32'h12345678;
        op2 = 32'd16;
        #1;
        check_result(32'h00001234, 0, 0, "0x12345678 >> 16 = 0x00001234 (logical)");
        
        //==============================================
        // Test 8: Shift Right Arithmetic (opsel = 3'b101, arith = 1)
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Shift Right Arithmetic", test_num);
        
        opsel = 3'b101;
        arith = 1;
        
        op1 = 32'h80000000;  // Negative number
        op2 = 32'd1;
        #1;
        check_result(32'hC0000000, 0, 1, "0x80000000 >> 1 = 0xC0000000 (arithmetic)");
        
        op1 = 32'h80000000;
        op2 = 32'd4;
        #1;
        check_result(32'hF8000000, 0, 1, "0x80000000 >> 4 = 0xF8000000 (arithmetic)");
        
        op1 = 32'hFFFFFFFF;  // -1
        op2 = 32'd8;
        #1;
        check_result(32'hFFFFFFFF, 0, 1, "0xFFFFFFFF >> 8 = 0xFFFFFFFF (arithmetic)");
        
        op1 = 32'h7FFFFFFF;  // Positive number
        op2 = 32'd4;
        #1;
        check_result(32'h07FFFFFF, 0, 0, "0x7FFFFFFF >> 4 = 0x07FFFFFF (arithmetic, positive)");
        
        op1 = 32'h12345678;  // Positive
        op2 = 32'd8;
        #1;
        check_result(32'h00123456, 0, 0, "0x12345678 >> 8 = 0x00123456 (arithmetic, positive)");
        
        //==============================================
        // Test 9: OR (opsel = 3'b110)
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: OR", test_num);
        
        opsel = 3'b110;
        arith = 0;
        
        op1 = 32'hAAAAAAAA;
        op2 = 32'h55555555;
        #1;
        check_result(32'hFFFFFFFF, 0, 1, "0xAAAAAAAA | 0x55555555 = 0xFFFFFFFF");
        
        op1 = 32'h00000000;
        op2 = 32'h00000000;
        #1;
        check_result(32'h00000000, 1, 0, "0 | 0 = 0");
        
        op1 = 32'h12340000;
        op2 = 32'h00005678;
        #1;
        check_result(32'h12345678, 0, 0, "0x12340000 | 0x00005678 = 0x12345678");
        
        //==============================================
        // Test 10: AND (opsel = 3'b111)
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: AND", test_num);
        
        opsel = 3'b111;
        
        op1 = 32'hAAAAAAAA;
        op2 = 32'h55555555;
        #1;
        check_result(32'h00000000, 0, 1, "0xAAAAAAAA & 0x55555555 = 0");
        
        op1 = 32'hFFFFFFFF;
        op2 = 32'hFFFFFFFF;
        #1;
        check_result(32'hFFFFFFFF, 1, 0, "0xFFFFFFFF & 0xFFFFFFFF = 0xFFFFFFFF");
        
        op1 = 32'h12345678;
        op2 = 32'hFF00FF00;
        #1;
        check_result(32'h12005600, 0, 0, "0x12345678 & 0xFF00FF00 = 0x12005600");
        
        //==============================================
        // Test 11: Equality Flag (o_eq)
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Equality Flag", test_num);
        
        opsel = 3'b000;
        sub = 0;
        
        op1 = 32'd100;
        op2 = 32'd100;
        #1;
        if (eq !== 1'b1) begin
            $display("  FAIL: eq should be 1 when op1 == op2");
            errors = errors + 1;
        end else begin
            $display("  PASS: eq = 1 when op1 == op2");
        end
        
        op1 = 32'd100;
        op2 = 32'd101;
        #1;
        if (eq !== 1'b0) begin
            $display("  FAIL: eq should be 0 when op1 != op2");
            errors = errors + 1;
        end else begin
            $display("  PASS: eq = 0 when op1 != op2");
        end
        
        //==============================================
        // Test 12: SLT Flag
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: SLT Flag (Signed)", test_num);
        
        unsigned_op = 0;
        
        op1 = 32'd10;
        op2 = 32'd20;
        #1;
        if (slt !== 1'b1) begin
            $display("  FAIL: slt should be 1 when 10 < 20 (signed)");
            errors = errors + 1;
        end else begin
            $display("  PASS: slt = 1 when 10 < 20");
        end
        
        op1 = 32'hFFFFFFFF;  // -1
        op2 = 32'd0;
        #1;
        if (slt !== 1'b1) begin
            $display("  FAIL: slt should be 1 when -1 < 0 (signed)");
            errors = errors + 1;
        end else begin
            $display("  PASS: slt = 1 when -1 < 0 (signed)");
        end
        
        test_num = test_num + 1;
        $display("\nTest %0d: SLT Flag (Unsigned)", test_num);
        
        unsigned_op = 1;
        
        op1 = 32'hFFFFFFFF;
        op2 = 32'd0;
        #1;
        if (slt !== 1'b0) begin
            $display("  FAIL: slt should be 0 when 0xFFFFFFFF < 0 (unsigned)");
            errors = errors + 1;
        end else begin
            $display("  PASS: slt = 0 when 0xFFFFFFFF > 0 (unsigned)");
        end
        
        //==============================================
        // Test 13: Edge Cases
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Edge Cases", test_num);
        
        // Zero operands
        opsel = 3'b000;
        sub = 0;
        unsigned_op = 0;
        op1 = 32'd0;
        op2 = 32'd0;
        #1;
        check_result(32'd0, 1, 0, "0 + 0 = 0");
        
        // Maximum values
        op1 = 32'hFFFFFFFF;
        op2 = 32'hFFFFFFFF;
        #1;
        expected = 32'hFFFFFFFE;
        check_result(expected, 1, 0, "0xFFFFFFFF + 0xFFFFFFFF");
        
        // Shift by 0
        opsel = 3'b001;
        op1 = 32'h12345678;
        op2 = 32'd0;
        #1;
        check_result(32'h12345678, 0, 0, "Shift by 0 = no change");
        
        //==============================================
        // Final Results
        //==============================================
        #20;
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total tests: %0d", test_num);
        if (errors == 0) begin
            $display("Status: ALL TESTS PASSED");
        end else begin
            $display("Status: %0d TEST(S) FAILED", errors);
        end
        $display("========================================\n");
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("\nERROR: Testbench timeout!");
        $finish;
    end

endmodule

`default_nettype wire
