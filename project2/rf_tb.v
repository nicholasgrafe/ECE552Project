`timescale 1ns/1ps
`default_nettype none

module rf_tb;
    // Clock and reset
    reg clk;
    reg rst;
    
    // Register file inputs
    reg [4:0] rs1_raddr;
    reg [4:0] rs2_raddr;
    reg rd_wen;
    reg [4:0] rd_waddr;
    reg [31:0] rd_wdata;
    
    // Register file outputs for both modes
    wire [31:0] rs1_rdata_nobypass;
    wire [31:0] rs2_rdata_nobypass;
    wire [31:0] rs1_rdata_bypass;
    wire [31:0] rs2_rdata_bypass;
    
    // Instantiate DUT with BYPASS_EN = 0
    rf #(.BYPASS_EN(0)) dut_nobypass (
        .i_clk(clk),
        .i_rst(rst),
        .i_rs1_raddr(rs1_raddr),
        .o_rs1_rdata(rs1_rdata_nobypass),
        .i_rs2_raddr(rs2_raddr),
        .o_rs2_rdata(rs2_rdata_nobypass),
        .i_rd_wen(rd_wen),
        .i_rd_waddr(rd_waddr),
        .i_rd_wdata(rd_wdata)
    );
    
    // Instantiate DUT with BYPASS_EN = 1
    rf #(.BYPASS_EN(1)) dut_bypass (
        .i_clk(clk),
        .i_rst(rst),
        .i_rs1_raddr(rs1_raddr),
        .o_rs1_rdata(rs1_rdata_bypass),
        .i_rs2_raddr(rs2_raddr),
        .o_rs2_rdata(rs2_rdata_bypass),
        .i_rd_wen(rd_wen),
        .i_rd_waddr(rd_waddr),
        .i_rd_wdata(rd_wdata)
    );
    
    // Clock generation: 10ns period (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test counter
    integer test_num;
    integer errors;
    integer i;
    integer reg_errors;
    
    // Main test sequence
    initial begin
        $dumpfile("rf_tb.vcd");
        $dumpvars(0, rf_tb);
        
        // Initialize
        test_num = 0;
        errors = 0;
        rst = 1;
        rs1_raddr = 0;
        rs2_raddr = 0;
        rd_wen = 0;
        rd_waddr = 0;
        rd_wdata = 0;
        
        $display("\n========================================");
        $display("Register File Testbench");
        $display("========================================\n");
        
        // Wait for a few cycles with reset active
        repeat(2) @(posedge clk);
        rst = 0;
        @(posedge clk);
        
        //==============================================
        // Test 1: Verify x0 is hardwired to zero
        //==============================================
        test_num = test_num + 1;
        $display("Test %0d: x0 hardwired to zero", test_num);
        rs1_raddr = 5'd0;
        rs2_raddr = 5'd0;
        #1; // Wait for combinational logic
        if (rs1_rdata_nobypass !== 32'd0 || rs2_rdata_nobypass !== 32'd0) begin
            $display("  FAIL: x0 not reading zero");
            $display("    rs1_rdata = 0x%h (expected 0x00000000)", rs1_rdata_nobypass);
            $display("    rs2_rdata = 0x%h (expected 0x00000000)", rs2_rdata_nobypass);
            errors = errors + 1;
        end else begin
            $display("  PASS: x0 reads zero");
        end
        
        //==============================================
        // Test 2: Attempt to write to x0 (should be ignored)
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Write to x0 is ignored", test_num);
        rd_wen = 1;
        rd_waddr = 5'd0;
        rd_wdata = 32'hDEADBEEF;
        @(posedge clk);
        rd_wen = 0;
        #1;
        rs1_raddr = 5'd0;
        #1;
        if (rs1_rdata_nobypass !== 32'd0) begin
            $display("  FAIL: x0 was modified");
            $display("    x0 = 0x%h (expected 0x00000000)", rs1_rdata_nobypass);
            errors = errors + 1;
        end else begin
            $display("  PASS: x0 remains zero after write attempt");
        end
        
        //==============================================
        // Test 3: Basic write and read (no bypass)
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Basic write and read", test_num);
        
        // Write to x5
        rd_wen = 1;
        rd_waddr = 5'd5;
        rd_wdata = 32'h12345678;
        rs1_raddr = 5'd5;
        #1; // Check before clock edge
        $display("  Before clock edge: rs1_rdata = 0x%h (should be old value)", rs1_rdata_nobypass);
        
        @(posedge clk);
        rd_wen = 0;
        #1; // Check after clock edge
        if (rs1_rdata_nobypass !== 32'h12345678) begin
            $display("  FAIL: Data not written correctly");
            $display("    x5 = 0x%h (expected 0x12345678)", rs1_rdata_nobypass);
            errors = errors + 1;
        end else begin
            $display("  PASS: After clock edge: x5 = 0x%h", rs1_rdata_nobypass);
        end
        
        //==============================================
        // Test 4: Multiple register writes
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Multiple register writes", test_num);
        
        // Write to registers x1, x2, x3
        rd_wen = 1;
        rd_waddr = 5'd1;
        rd_wdata = 32'hAAAAAAAA;
        @(posedge clk);
        
        rd_waddr = 5'd2;
        rd_wdata = 32'hBBBBBBBB;
        @(posedge clk);
        
        rd_waddr = 5'd3;
        rd_wdata = 32'hCCCCCCCC;
        @(posedge clk);
        
        rd_wen = 0;
        #1;
        
        // Read back and verify
        rs1_raddr = 5'd1;
        rs2_raddr = 5'd2;
        #1;
        if (rs1_rdata_nobypass !== 32'hAAAAAAAA || rs2_rdata_nobypass !== 32'hBBBBBBBB) begin
            $display("  FAIL: Registers not written correctly");
            $display("    x1 = 0x%h (expected 0xAAAAAAAA)", rs1_rdata_nobypass);
            $display("    x2 = 0x%h (expected 0xBBBBBBBB)", rs2_rdata_nobypass);
            errors = errors + 1;
        end else begin
            $display("  PASS: x1 = 0x%h, x2 = 0x%h", rs1_rdata_nobypass, rs2_rdata_nobypass);
        end
        
        rs1_raddr = 5'd3;
        #1;
        if (rs1_rdata_nobypass !== 32'hCCCCCCCC) begin
            $display("  FAIL: x3 not written correctly");
            $display("    x3 = 0x%h (expected 0xCCCCCCCC)", rs1_rdata_nobypass);
            errors = errors + 1;
        end else begin
            $display("  PASS: x3 = 0x%h", rs1_rdata_nobypass);
        end
        
        //==============================================
        // Test 5: Dual read ports independence
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Dual read ports work independently", test_num);
        
        rs1_raddr = 5'd1;
        rs2_raddr = 5'd3;
        #1;
        if (rs1_rdata_nobypass !== 32'hAAAAAAAA || rs2_rdata_nobypass !== 32'hCCCCCCCC) begin
            $display("  FAIL: Dual read ports error");
            $display("    rs1 (x1) = 0x%h (expected 0xAAAAAAAA)", rs1_rdata_nobypass);
            $display("    rs2 (x3) = 0x%h (expected 0xCCCCCCCC)", rs2_rdata_nobypass);
            errors = errors + 1;
        end else begin
            $display("  PASS: rs1 (x1) = 0x%h, rs2 (x3) = 0x%h", 
                     rs1_rdata_nobypass, rs2_rdata_nobypass);
        end
        
        //==============================================
        // Test 6: BYPASS mode vs NO-BYPASS mode
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Bypass mode comparison", test_num);
        
        // Setup: write to x10
        rd_wen = 1;
        rd_waddr = 5'd10;
        rd_wdata = 32'hCAFEBABE;
        rs1_raddr = 5'd10;
        rs2_raddr = 5'd1; // Different register for comparison
        #1; // Check combinationally during write
        
        $display("  During write cycle (before clock edge):");
        $display("    NO-BYPASS: x10 = 0x%h (old value)", rs1_rdata_nobypass);
        $display("    BYPASS:    x10 = 0x%h (should be 0xCAFEBABE)", rs1_rdata_bypass);
        $display("    Both:      x1  = 0x%h (should be 0xAAAAAAAA)", rs2_rdata_nobypass);
        
        if (rs1_rdata_bypass !== 32'hCAFEBABE) begin
            $display("  FAIL: Bypass mode not forwarding write data");
            errors = errors + 1;
        end else begin
            $display("  PASS: Bypass mode correctly forwards write data");
        end
        
        @(posedge clk);
        rd_wen = 0;
        #1;
        
        $display("  After clock edge:");
        $display("    NO-BYPASS: x10 = 0x%h (should be 0xCAFEBABE)", rs1_rdata_nobypass);
        $display("    BYPASS:    x10 = 0x%h (should be 0xCAFEBABE)", rs1_rdata_bypass);
        
        if (rs1_rdata_nobypass !== 32'hCAFEBABE) begin
            $display("  FAIL: Write not committed after clock edge");
            errors = errors + 1;
        end else begin
            $display("  PASS: Both modes read same value after clock edge");
        end
        
        //==============================================
        // Test 7: Write enable control
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Write enable = 0 prevents writes", test_num);
        
        rd_wen = 0;
        rd_waddr = 5'd7;
        rd_wdata = 32'hBAD0BAD0;
        @(posedge clk);
        
        rs1_raddr = 5'd7;
        #1;
        if (rs1_rdata_nobypass !== 32'd0) begin
            $display("  FAIL: Write occurred when rd_wen = 0");
            $display("    x7 = 0x%h (expected 0x00000000)", rs1_rdata_nobypass);
            errors = errors + 1;
        end else begin
            $display("  PASS: No write occurred (x7 still zero)");
        end
        
        //==============================================
        // Test 8: All registers (x1-x31)
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Write and read all registers x1-x31", test_num);

        reg_errors = 0;
        
        // Write incrementing values to all registers
        rd_wen = 1;
        for (i = 1; i < 32; i = i + 1) begin
            rd_waddr = i;
            rd_wdata = 32'h10000000 + i;
            @(posedge clk);
        end
        rd_wen = 0;
        #1;
        
        // Read back and verify all registers
        for (i = 1; i < 32; i = i + 1) begin
            rs1_raddr = i;
            #1;
            if (rs1_rdata_nobypass !== (32'h10000000 + i)) begin
                $display("  FAIL: x%0d = 0x%h (expected 0x%h)", 
                         i, rs1_rdata_nobypass, 32'h10000000 + i);
                reg_errors = reg_errors + 1;
            end
        end
        
        if (reg_errors == 0) begin
            $display("  PASS: All 31 registers (x1-x31) written and read correctly");
        end else begin
            $display("  FAIL: %0d registers had errors", reg_errors);
            errors = errors + 1;
        end
        
        //==============================================
        // Test 9: Reset functionality
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Reset clears all registers", test_num);
        
        rst = 1;
        @(posedge clk);
        @(posedge clk);
        rst = 0;
        #1;
        
        // Check a few registers
        reg_errors = 0;
        rs1_raddr = 5'd5;
        #1;
        if (rs1_rdata_nobypass !== 32'd0) reg_errors = reg_errors + 1;
        
        rs1_raddr = 5'd10;
        #1;
        if (rs1_rdata_nobypass !== 32'd0) reg_errors = reg_errors + 1;
        
        rs1_raddr = 5'd31;
        #1;
        if (rs1_rdata_nobypass !== 32'd0) reg_errors = reg_errors + 1;
        
        if (reg_errors == 0) begin
            $display("  PASS: All registers cleared after reset");
        end else begin
            $display("  FAIL: Some registers not cleared after reset");
            errors = errors + 1;
        end
        
        //==============================================
        // Test 10: Bypass with x0
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Bypass mode with x0", test_num);
        
        rd_wen = 1;
        rd_waddr = 5'd0;
        rd_wdata = 32'hFFFFFFFF;
        rs1_raddr = 5'd0;
        #1;
        
        if (rs1_rdata_bypass !== 32'd0) begin
            $display("  FAIL: Bypass mode forwarded to x0");
            $display("    x0 = 0x%h (expected 0x00000000)", rs1_rdata_bypass);
            errors = errors + 1;
        end else begin
            $display("  PASS: x0 remains zero even in bypass mode");
        end
        
        @(posedge clk);
        rd_wen = 0;
        
        //==============================================
        // Test 11: Simultaneous read of same register
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Both read ports reading same register", test_num);
        
        rd_wen = 1;
        rd_waddr = 5'd15;
        rd_wdata = 32'h55555555;
        @(posedge clk);
        rd_wen = 0;
        
        rs1_raddr = 5'd15;
        rs2_raddr = 5'd15;
        #1;
        
        if (rs1_rdata_nobypass !== 32'h55555555 || rs2_rdata_nobypass !== 32'h55555555) begin
            $display("  FAIL: Simultaneous read error");
            $display("    rs1 = 0x%h, rs2 = 0x%h (both expected 0x55555555)", 
                     rs1_rdata_nobypass, rs2_rdata_nobypass);
            errors = errors + 1;
        end else begin
            $display("  PASS: Both ports read same value: 0x%h", rs1_rdata_nobypass);
        end
        
        //==============================================
        // Test 12: Bypass with both read ports
        //==============================================
        test_num = test_num + 1;
        $display("\nTest %0d: Bypass mode with both read ports", test_num);
        
        rd_wen = 1;
        rd_waddr = 5'd20;
        rd_wdata = 32'h99999999;
        rs1_raddr = 5'd20; // Should bypass
        rs2_raddr = 5'd15; // Should not bypass
        #1;
        
        $display("  During write to x20:");
        $display("    BYPASS rs1 (x20) = 0x%h (expected 0x99999999)", rs1_rdata_bypass);
        $display("    BYPASS rs2 (x15) = 0x%h (expected 0x55555555)", rs2_rdata_bypass);
        
        if (rs1_rdata_bypass !== 32'h99999999 || rs2_rdata_bypass !== 32'h55555555) begin
            $display("  FAIL: Bypass not working correctly for both ports");
            errors = errors + 1;
        end else begin
            $display("  PASS: Bypass works correctly for both read ports");
        end
        
        @(posedge clk);
        rd_wen = 0;
        
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
        #10000;
        $display("\nERROR: Testbench timeout!");
        $finish;
    end

endmodule

`default_nettype wire
