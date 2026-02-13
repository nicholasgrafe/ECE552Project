`timescale 1ns/1ps
`default_nettype none

module imm_tb;
    reg [31:0] inst;
    reg [5:0] format;
    wire [31:0] immediate;
    
    imm dut (
        .i_inst(inst),
        .i_format(format),
        .o_immediate(immediate)
    );
    
    initial begin
        $dumpfile("imm_tb.vcd");
        $dumpvars(0, imm_tb);
        
        // Test I-type: ADDI x1, x2, 123
        // Format: imm[11:0] | rs1[4:0] | funct3[2:0] | rd[4:0] | opcode[6:0]
        // 000001111011 | 00010 | 000 | 00001 | 0010011
        inst = 32'b000001111011_00010_000_00001_0010011;
        format = 6'b000010; // I-type
        #10;
        $display("I-type: inst=%h, imm=%d (expected: 123)", inst, $signed(immediate));
        
        // Test I-type with negative immediate: ADDI x1, x2, -5
        // -5 = 0xFFB = 111111111011
        inst = 32'b111111111011_00010_000_00001_0010011;
        format = 6'b000010; // I-type
        #10;
        $display("I-type (neg): inst=%h, imm=%d (expected: -5)", inst, $signed(immediate));
        
        // Test S-type: SW x3, 100(x2)
        // Format: imm[11:5] | rs2[4:0] | rs1[4:0] | funct3[2:0] | imm[4:0] | opcode[6:0]
        // 100 = 0x64 = 0001100100
        // imm[11:5] = 0000011, imm[4:0] = 00100
        inst = 32'b0000011_00011_00010_010_00100_0100011;
        format = 6'b000100; // S-type
        #10;
        $display("S-type: inst=%h, imm=%d (expected: 100)", inst, $signed(immediate));
        
        // Test S-type with negative: SW x3, -20(x2)
        // -20 = 0xFEC = 111111101100
        // imm[11:5] = 1111111, imm[4:0] = 01100
        inst = 32'b1111111_00011_00010_010_01100_0100011;
        format = 6'b000100; // S-type
        #10;
        $display("S-type (neg): inst=%h, imm=%d (expected: -20)", inst, $signed(immediate));
        
        // Test B-type: BEQ x1, x2, 8
        // Format: imm[12] | imm[10:5] | rs2 | rs1 | funct3 | imm[4:1] | imm[11] | opcode
        // 8 = 0b1000, so imm[12]=0, imm[11]=0, imm[10:5]=000000, imm[4:1]=0100, imm[0]=0
        // inst[31]=0, inst[30:25]=000000, inst[11:8]=0100, inst[7]=0
        inst = 32'b0_000000_00010_00001_000_0100_0_1100011;
        format = 6'b001000; // B-type
        #10;
        $display("B-type: inst=%h, imm=%d (expected: 8)", inst, $signed(immediate));
        
        // Test B-type with negative: BEQ x1, x2, -16
        // -16 = 0xFFF0 = 1111111110000
        // imm[12]=1, imm[11]=1, imm[10:5]=111111, imm[4:1]=1000, imm[0]=0
        // inst[31]=1, inst[30:25]=111111, inst[11:8]=1000, inst[7]=1
        inst = 32'b1_111111_00010_00001_000_1000_1_1100011;
        format = 6'b001000; // B-type
        #10;
        $display("B-type (neg): inst=%h, imm=%d (expected: -16)", inst, $signed(immediate));
        
        // Test U-type: LUI x1, 0x12345
        // Format: imm[31:12] | rd | opcode
        inst = 32'b00010010001101000101_00001_0110111;
        format = 6'b010000; // U-type
        #10;
        $display("U-type: inst=%h, imm=%h (expected: 0x12345000)", inst, immediate);
        
        // Test U-type with sign bit set: LUI x1, 0x80000
        inst = 32'b10000000000000000000_00001_0110111;
        format = 6'b010000; // U-type
        #10;
        $display("U-type (high): inst=%h, imm=%h (expected: 0x80000000)", inst, immediate);
        
        // Test J-type: JAL x1, 20
        // Format: imm[20] | imm[10:1] | imm[11] | imm[19:12] | rd | opcode
        // Instruction bits: inst[31] | inst[30:21] | inst[20] | inst[19:12] | inst[11:7] | inst[6:0]
        // 20 = 0x14 = 0b00000000000000010100
        // imm[20]=0, imm[19:12]=00000000, imm[11]=0, imm[10:5]=000000, imm[4:1]=1010, imm[0]=0
        // inst[31]=0, inst[30:25]=000000, inst[24:21]=1010, inst[20]=0, inst[19:12]=00000000
        inst = 32'b0_000000_1010_0_00000000_00001_1101111;
        format = 6'b100000; // J-type
        #10;
        $display("J-type: inst=%h, imm=%d (expected: 20)", inst, $signed(immediate));
        
        // Test J-type with negative offset: JAL x1, -16
        // -16 = 0xFFFFF0 (sign-extended) = 0b111111111111111110000
        // imm[20]=1, imm[19:12]=11111111, imm[11]=1, imm[10:5]=111111, imm[4:1]=1000, imm[0]=0
        // inst[31]=1, inst[30:25]=111111, inst[24:21]=1000, inst[20]=1, inst[19:12]=11111111
        inst = 32'b1_111111_1000_1_11111111_00001_1101111;
        format = 6'b100000; // J-type
        #10;
        $display("J-type (neg): inst=%h, imm=%d (expected: -16)", inst, $signed(immediate));
        
        // Test J-type with larger offset: JAL x1, 2048
        // 2048 = 0x800 = 0b100000000000
        // imm[20]=0, imm[11]=1, imm[10:1]=0000000000
        // inst[31]=0, inst[30:25]=000000, inst[24:21]=0000, inst[20]=1, inst[19:12]=00000000
        inst = 32'b0_000000_0000_1_00000000_00001_1101111;
        format = 6'b100000; // J-type
        #10;
        $display("J-type (large): inst=%h, imm=%d (expected: 2048)", inst, $signed(immediate));
        
        $finish;
    end
endmodule

`default_nettype wire
