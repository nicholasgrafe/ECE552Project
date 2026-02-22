`default_nettype none

// Control unit for RV32I single-cycle processor
module control (
    // takes 7-bit opcode
    input wire [ 6:0 ] i_opcode,

    // immediate decode controls
    output reg [ 5:0 ] o_imm_fmt;

    // register file controls
    output reg o_rd_wen,
    output reg o_lui_en, // determines which U type instruction we want to store
    output reg o_i_type_u, // determines if we want to store U type result or other mux result in rd

    // ALU controls
    output reg o_alu_imm,

    // Memory controls
    output reg o_dmem_ren,
    output reg o_dmem_wen,
    output reg o_mem_to_reg,

    // PC/jump/branch controls
    output reg o_branch_en,
    output reg o_jump_sel,
    output reg o_i_type_j // determines type of jump and if we want to store pc + 4 into rd
);
    localparam OP_LUI = 7'b0110111;
    localparam OP_AUIPC = 7'b0010111;
    localparam OP_JAL = 7'b1101111;
    localparam OP_JALR = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD = 7'b0000011;
    localparam OP_STORE = 7'b0100011;
    localparam OP_IMM = 7'b0010011;
    localparam OP_REG = 7'b0110011;

    localparam R_TYPE = 6'b000001;
    localparam I_TYPE = 6'b000010;
    localparam S_TYPE = 6'b000100;
    localparam B_TYPE = 6'b001000;
    localparam U_TYPE = 6'b010000;
    localparam J_TYPE = 6'b100000;

    always @(*) begin
        // Defaults
        o_imm_fmt = R_TYPE;
        o_rd_wen = 1'b0;
        o_lui_en = 1'b0;
        o_i_type_u = 1'b0;
        o_alu_imm = 1'b0;
        o_dmem_ren = 1'b0;
        o_dmem_wen = 1'b0;
        o_mem_to_reg = 1'b0;
        o_branch_en = 1'b0;
        o_jump_sel = 1'b0;
        o_i_type_j = 1'b0;

        case (i_opcode)
            OP_REG: begin
                o_rd_wen = 1'b1;
                o_alu_imm = 1'b0;
                o_mem_to_reg = 1'b0;
                o_imm_fmt = R_TYPE;
            end
            OP_IMM: begin
                o_rd_wen = 1'b1;
                o_alu_imm = 1'b1;
                o_mem_to_reg = 1'b0;
                o_imm_fmt = I_TYPE;
            end
            OP_LOAD: begin
                o_rd_wen = 1'b1;
                o_alu_imm = 1'b1;
                o_dmem_ren = 1'b1;
                o_mem_to_reg = 1'b1;
                o_imm_fmt = I_TYPE;
            end
            OP_STORE: begin
                o_alu_imm = 1'b1;
                o_dmem_wen = 1'b1;
                o_imm_fmt = S_TYPE;
            end
            OP_BRANCH: begin
                o_branch_en = 1'b1;
                o_imm_fmt = B_TYPE;
            end
            OP_JAL: begin
                o_rd_wen = 1'b1;
                o_i_type_j = 1'b1;
                o_jump_sel = 1'b1;
                o_imm_fmt = J_TYPE;
            end
            OP_JALR: begin
                o_rd_wen = 1'b1;
                o_alu_imm = 1'b1;
                o_i_type_j = 1'b1;
                o_jump_sel = 1'b0;
                o_imm_fmt = I_TYPE;
            end
            OP_LUI: begin
                o_rd_wen = 1'b1;
                o_lui_en = 1'b1;
                o_i_type_u = 1'b1;
                o_imm_fmt = U_TYPE;
            end
            OP_AUIPC: begin
                o_rd_wen = 1'b1;
                o_lui_en = 1'b0;
                o_i_type_u = 1'b1;
                o_i_type_u = U_TYPE;
            end
            default: begin
                // add default case
            end
        endcase
    end

endmodule

`default_nettype wire