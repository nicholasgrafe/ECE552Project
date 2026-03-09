`default_nettype none

// Forwarding unit for RISC-V processor
module fwdu (
    // Source register addresses of the instruction currently in EX stage
    input  wire [4:0] i_ex_rs1_raddr,
    input  wire [4:0] i_ex_rs2_raddr,

    // EX/MEM register (instruction in MEM stage)
    input  wire       i_mem_rd_wen,
    input  wire [4:0] i_mem_rd_waddr,

    // MEM/WB register (instruction in WB stage)
    input  wire       i_wb_rd_wen,
    input  wire [4:0] i_wb_rd_waddr,

    // forwarding mux select signals (outputs)
    output wire [1:0] o_fwd_rs1_sel,
    output wire [1:0] o_fwd_rs2_sel
);

    // EX-to-EX
    wire fwd_ex_rs1 = i_mem_rd_wen && (i_mem_rd_waddr != 5'd0) && (i_mem_rd_waddr == i_ex_rs1_raddr);
    wire fwd_ex_rs2 = i_mem_rd_wen && (i_mem_rd_waddr != 5'd0) && (i_mem_rd_waddr == i_ex_rs2_raddr);

    // MEM-to-EX
    wire fwd_mem_rs1 = i_wb_rd_wen && (i_wb_rd_waddr != 5'd0) && (i_wb_rd_waddr == i_ex_rs1_raddr);
    wire fwd_mem_rs2 = i_wb_rd_wen && (i_wb_rd_waddr != 5'd0) && (i_wb_rd_waddr == i_ex_rs2_raddr);

    // 2-bit forwarding select for rs1 and rs2:
    // 2'b00 = no forwarding
    // 2'b01 = EX-to-EX
    // 2'b10 = MEM-to-EX
    assign o_fwd_rs1_sel = fwd_ex_rs1 ? 2'b01 : (fwd_mem_rs1 ? 2'b10 : 2'b00);
    assign o_fwd_rs2_sel = fwd_ex_rs2 ? 2'b01 : (fwd_mem_rs2 ? 2'b10 : 2'b00);

endmodule

`default_nettype wire
