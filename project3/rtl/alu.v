`default_nettype none

// The arithmetic logic unit (ALU) is responsible for performing the core
// calculations of the processor. It takes two 32-bit operands and outputs
// a 32 bit result based on the selection operation - addition, comparison,
// shift, or logical operation. This ALU is a purely combinational block, so
// you should not attempt to add any registers or pipeline it.
module alu (
    // NOTE: Both 3'b010 and 3'b011 are used for set less than operations and
    // your implementation should output the same result for both codes. The
    // reason for this will become clear in project 3.
    //
    // Major operation selection.
    // 3'b000: addition/subtraction if `i_sub` asserted
    // 3'b001: shift left logical
    // 3'b010,
    // 3'b011: set less than/unsigned if `i_unsigned` asserted
    // 3'b100: exclusive or
    // 3'b101: shift right logical/arithmetic if `i_arith` asserted
    // 3'b110: or
    // 3'b111: and
    input  wire [ 2:0] i_opsel,
    // When asserted, addition operations should subtract instead.
    // This is only used for `i_opsel == 3'b000` (addition/subtraction).
    input  wire        i_sub,
    // When asserted, comparison operations should be treated as unsigned.
    // This is used for branch comparisons and set less than unsigned. For
    // branch operations, the ALU result is not used, only the comparison
    // results.
    input  wire        i_unsigned,
    // When asserted, right shifts should be treated as arithmetic instead of
    // logical. This is only used for `i_opsel == 3'b101` (shift right).
    input  wire        i_arith,
    // First 32-bit input operand.
    input  wire [31:0] i_op1,
    // Second 32-bit input operand.
    input  wire [31:0] i_op2,
    // 32-bit output result. Any carry out should be ignored.
    output wire [31:0] o_result,
    // Equality result. This is used externally to determine if a branch
    // should be taken.
    output wire        o_eq,
    // Set less than result. This is used externally to determine if a branch
    // should be taken.
    output wire        o_slt
);
    // addition/subtraction operation
    wire [31:0] add_sub_op2 = i_sub ? ~i_op2 : i_op2;
    wire [31:0] add_sub_result = i_op1 + add_sub_op2 + (i_sub ? 1'b1 : 1'b0);

    // shift left logical operation (op1 gets shifted by op2[4:0] bits)
    wire [31:0] sll_shift0 = (i_op2[0]) ? {i_op1[30:0], 1'b0} : i_op1;
    wire [31:0] sll_shift1 = (i_op2[1]) ? {sll_shift0[29:0], 2'b00} : sll_shift0;
    wire [31:0] sll_shift2 = (i_op2[2]) ? {sll_shift1[27:0], 4'b0000} : sll_shift1;
    wire [31:0] sll_shift3 = (i_op2[3]) ? {sll_shift2[23:0], 8'b00000000} : sll_shift2;
    wire [31:0] sll_result = (i_op2[4]) ? {sll_shift3[15:0], 16'b0000000000000000} : sll_shift3;

    // set less than operation (both signed and unsigned)
    wire signed [31:0] signed_op1 = i_op1;
    wire signed [31:0] signed_op2 = i_op2;
    wire [31:0] slt_result = i_unsigned ? (i_op1 < i_op2 ? 32'd1 : 32'd0) : (signed_op1 < signed_op2 ? 32'd1 : 32'd0);

    // shift right logical/arithmetic operation (op1 gets shifted by op2[4:0] bits)
    wire [31:0] srl_shift0 = (i_op2[0]) ? {i_arith ? i_op1[31] : 1'b0, i_op1[31:1]} : i_op1;
    wire [31:0] srl_shift1 = (i_op2[1]) ? {{2{i_arith ? srl_shift0[31] : 1'b0}}, srl_shift0[31:2]} : srl_shift0;
    wire [31:0] srl_shift2 = (i_op2[2]) ? {{4{i_arith ? srl_shift1[31] : 1'b0}}, srl_shift1[31:4]} : srl_shift1;
    wire [31:0] srl_shift3 = (i_op2[3]) ? {{8{i_arith ? srl_shift2[31] : 1'b0}}, srl_shift2[31:8]} : srl_shift2;
    wire [31:0] srl_result = (i_op2[4]) ? {{16{i_arith ? srl_shift3[31] : 1'b0}}, srl_shift3[31:16]} : srl_shift3;

    // mux logic based on i_opsel control signal
    assign o_result = (i_opsel == 3'b000) ? add_sub_result :
                      (i_opsel == 3'b001) ? sll_result :
                      (i_opsel == 3'b010 || i_opsel == 3'b011) ? slt_result :
                      (i_opsel == 3'b100) ? (i_op1 ^ i_op2) : // xor operation
                      (i_opsel == 3'b101) ? srl_result :
                      (i_opsel == 3'b110) ? (i_op1 | i_op2) : // or operation
                      (i_opsel == 3'b111) ? (i_op1 & i_op2) : // and operation
                      32'b0;

    assign o_eq = (i_op1 == i_op2);
    assign o_slt = i_unsigned ? (i_op1 < i_op2) : (signed_op1 < signed_op2);
endmodule

`default_nettype wire
