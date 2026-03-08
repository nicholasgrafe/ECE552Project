`default_nettype none

// hazard detection unit for RISC-V processor
module hdu (
    // Source register addresses of the current instruction in ID
    input  wire [4:0] i_id_rs1,
    input  wire [4:0] i_id_rs2,

    // ID/EX inputs
    input  wire       i_ex_rd_wen,
    input  wire [4:0] i_ex_rd_waddr,

    // EX/MEM inputs
    input  wire       i_mem_rd_wen,
    input  wire [4:0] i_mem_rd_waddr,

    // Asserted when a data hazard is detected
    output wire       o_stall
);

    // Hazards from the instruction in EX (one cycle ahead of ID):
    wire hazard_ex_rs1 = i_ex_rd_wen && (i_ex_rd_waddr != 5'd0) && (i_ex_rd_waddr == i_id_rs1);
    wire hazard_ex_rs2 = i_ex_rd_wen && (i_ex_rd_waddr != 5'd0) && (i_ex_rd_waddr == i_id_rs2);

    // Hazards from the instruction in MEM (two cycles ahead of ID):
    wire hazard_mem_rs1 = i_mem_rd_wen && (i_mem_rd_waddr != 5'd0) && (i_mem_rd_waddr == i_id_rs1);
    wire hazard_mem_rs2 = i_mem_rd_wen && (i_mem_rd_waddr != 5'd0) && (i_mem_rd_waddr == i_id_rs2);

    assign o_stall = hazard_ex_rs1 | hazard_ex_rs2 | hazard_mem_rs1 | hazard_mem_rs2;

endmodule

`default_nettype wire