`default_nettype none

// Hazard detection unit for RISC-V processor
module hdu (
    // Source register addresses of the current instruction in ID
    input  wire [4:0] i_id_rs1,
    input  wire [4:0] i_id_rs2,

    // ID/EX inputs
    input  wire       i_ex_rd_wen,
    input  wire [4:0] i_ex_rd_waddr,
    input  wire       i_ex_dmem_ren,

    // Asserted on load-to-use stalls
    output wire       o_stall
);

    // Check if lw -> some op and rd = rs/rt
    wire hazard_load_rs1 = i_ex_rd_wen && i_ex_dmem_ren && (i_ex_rd_waddr != 5'd0) && (i_ex_rd_waddr == i_id_rs1);
    wire hazard_load_rs2 = i_ex_rd_wen && i_ex_dmem_ren && (i_ex_rd_waddr != 5'd0) && (i_ex_rd_waddr == i_id_rs2);

    assign o_stall = hazard_load_rs1 | hazard_load_rs2;

endmodule

`default_nettype wire
