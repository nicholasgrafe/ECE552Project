`default_nettype none

// Branch logic module
module branch_logic (
    input wire[2:0] i_funct3,
    input wire i_eq,
    input wire i_slt,
    input wire i_branch_en,
    output wire o_branch
);
    // stores value of branch condition
    reg cond;

    always @(*) begin
        case (i_funct3)
            3'b000: cond = i_eq;            // BEQ
            3'b001: cond = ~i_eq;           // BNE
            3'b100, 3'b110: cond = i_slt;   // BLT, BLTU
            3'b101, 3'b111: cond = ~i_slt;  // BGE, BGEU
            default: cond = 1'b0;
        endcase
    end

    assign o_branch = i_branch_en & cond;

endmodule

`default_nettype wire