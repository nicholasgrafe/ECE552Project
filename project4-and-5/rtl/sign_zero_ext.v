`default_nettype none

// Sign/Zero-Extension for load operations
module sign_zero_ext (
    input wire [31:0] i_dmem_rdata,
    input wire [2:0] i_funct3,
    input wire [1:0] i_byte_offset,
    output wire [31:0] o_dmem_ext
);
    wire [7:0] byte_val;
    wire [15:0] hw_val;

    // Byte selection based on offset
    assign byte_val = (i_byte_offset == 2'b00) ? i_dmem_rdata[ 7: 0] :
                          (i_byte_offset == 2'b01) ? i_dmem_rdata[15: 8] :
                          (i_byte_offset == 2'b10) ? i_dmem_rdata[23:16] :
                                                     i_dmem_rdata[31:24];

    // Halfword selection (aligned: offset 0 or 2)
    assign hw_val = i_byte_offset[1] ? i_dmem_rdata[31:16] : i_dmem_rdata[15:0];

    assign o_dmem_ext = (i_funct3 == 3'b000) ? {{24{byte_val[7]}},  byte_val}  	:  // LB
                        (i_funct3 == 3'b001) ? {{16{hw_val[15]}}, hw_val}  	:  // LH
                        (i_funct3 == 3'b100) ? {24'b0, byte_val}               	:  // LBU
                        (i_funct3 == 3'b101) ? {16'b0, hw_val}               	:  // LHU
                                               i_dmem_rdata;                       // LW (default)

endmodule

`default_nettype wire