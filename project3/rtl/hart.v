module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available on the same cycle.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `i_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002000`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // this will immediately reflect the contents of memory at the specified
    // address, for the bytes enabled by the mask. When read enable is not
    // asserted, or for bytes not set in the mask, the value is undefined.
    input  wire [31:0] i_dmem_rdata,
	// The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);

    // Fill in your implementation here.

    // =========================================================================
    // PROGRAM COUNTER
    // =========================================================================
    reg [31:0] pc;

    always @(posedge i_clk) begin
        if (i_rst)
            pc <= RESET_ADDR;
        else
            pc <= next_pc;
    end

    // =========================================================================
    // INSTRUCTION FETCH
    // =========================================================================
    wire [31:0] instruction;
    wire [2:0] funct3;
    wire [6:0] funct7;

    assign o_imem_raddr = pc;
    assign instruction = i_imem_rdata;
    
    // =========================================================================
    // DECODE LOGIC
    // =========================================================================
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    // Control unit wires
    wire [5:0] ctrl_imm_fmt;
    wire       ctrl_rd_wen;
    wire       ctrl_i_type_lui;
    wire       ctrl_i_type_unsigned;
    wire       ctrl_alu_imm;
    wire       ctrl_dmem_ren;
    wire       ctrl_dmem_wen;
    wire       ctrl_mem_to_reg;
    wire       ctrl_branch_en;
    wire       ctrl_jump_sel;
    wire       ctrl_i_type_jmp;

    control ctrl_unit(
        .i_opcode    (instruction[6:0]),
        .o_imm_fmt   (ctrl_imm_fmt),
        .o_rd_wen    (ctrl_rd_wen),
        .o_lui_en    (ctrl_i_type_lui),
        .o_i_type_u  (ctrl_i_type_unsigned),
        .o_alu_imm   (ctrl_alu_imm),
        .o_dmem_ren  (ctrl_dmem_ren),
        .o_dmem_wen  (ctrl_dmem_wen),
        .o_mem_to_reg(ctrl_mem_to_reg),
        .o_branch_en (ctrl_branch_en),
        .o_jump_sel  (ctrl_jump_sel),
        .o_i_type_j  (ctrl_i_type_jmp)
    );

    // =========================================================================
    // IMMEDIATE DECODER
    // =========================================================================
    wire [31:0] immediate;

    imm imm_decoder (
        .i_inst     (instruction),
        .i_format   (ctrl_imm_fmt),
        .o_immediate(immediate)
    );

    // =========================================================================
    // REGFILE
    // =========================================================================
    wire [31:0] rs1_rdata;
    wire [31:0] rs2_rdata;
    wire [31:0] rd_wdata;

    // need to insert the writeback muxes that determine rd_wdata;

    rf #(.BYPASS_EN(0)) regfile (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .i_rs1_raddr(instruction[19:15]),
        .o_rs1_rdata(rs1_rdata),
        .i_rs2_raddr(instruction[24:20]),
        .o_rs2_rdata(rs2_rdata),
        .i_rd_wen   (ctrl_rd_wen),
        .i_rd_waddr (instruction[11:7]),
        .i_rd_wdata (rd_wdata)
    );

    // =========================================================================
    // ALU / EXECUTE LOGIC
    // =========================================================================
    wire [31:0] alu_op2;
    wire [31:0] alu_result;
    wire        alu_eq;
    wire        alu_slt;

    assign alu_op2 = ctrl_alu_imm ? immediate : rs2_rdata;

    alu alu_inst (
        .i_opsel   (funct3),
        .i_sub     (funct7[5]),
        .i_unsigned(funct3[0]),
        .i_arith   (funct7[5]),
        .i_op1     (rs1_rdata),
        .i_op2     (alu_op2),
        .o_result  (alu_result),
        .o_eq      (alu_eq),
        .o_slt     (alu_slt)
    );

    // =========================================================================
    // BRANCH LOGIC
    // =========================================================================
    wire branch_result;

    branch_logic branch_logic_inst (
        .i_funct3   (funct3),
        .i_eq       (alu_eq),
        .i_slt      (alu_slt),
        .i_branch_en(ctrl_branch_en),
        .o_branch   (branch_result)
    );

    // =========================================================================
    // UPDATE PC LOGIC / JUMP LOGIC
    // =========================================================================

    wire[31:0] pc_plus_4;
    assign pc_plus_4 = pc + 32'd4;

    wire [31:0] pc_plus_imm;
    assign pc_plus_imm = pc + immediate;

    wire [31:0] jalr_target;
    assign jalr_target = alu_result & 32'hfffffffe;

    wire [31:0] next_pc;

    assign next_pc =
        (ctrl_i_type_jmp & !ctrl_jump_sel)  ? jalr_target : // JALR
        (ctrl_i_type_jmp & ctrl_jump_sel)   ? pc_plus_imm : // JAL
        branch_result                       ? pc_plus_imm : // Branch
        pc_plus_4;                                          // Default 

    // =========================================================================
    // MEMORY / WRITEBACK LOGIC
    // =========================================================================
    wire [31:0] mem_addr   = alu_result;
    wire [1:0]  mem_offset = mem_addr[1:0];

    // --- DMEM address (word-aligned) ---
    assign o_dmem_addr = {mem_addr[31:2], 2'b00};

    // --- Read / write enables ---
    assign o_dmem_ren = ctrl_dmem_ren;
    assign o_dmem_wen = ctrl_dmem_wen;

    // --- Byte mask ---
    wire [3:0] byte_mask = (mem_offset == 2'b00) ? 4'b0001 :
                           (mem_offset == 2'b01) ? 4'b0010 :
                           (mem_offset == 2'b10) ? 4'b0100 :
                                                   4'b1000;
    wire [3:0] half_mask = mem_offset[1] ? 4'b1100 : 4'b0011;

    assign o_dmem_mask = (funct3[1:0] == 2'b00) ? byte_mask :
                         (funct3[1:0] == 2'b01) ? half_mask :
                                                  4'b1111;      // word

    // --- Write data (shift value into correct byte lane) ---
    wire [31:0] sb_wdata = (mem_offset == 2'b00) ? {24'b0, rs2_rdata[ 7:0]        } :
                           (mem_offset == 2'b01) ? {16'b0, rs2_rdata[ 7:0],  8'b0 } :
                           (mem_offset == 2'b10) ? { 8'b0, rs2_rdata[ 7:0], 16'b0 } :
                                                   {       rs2_rdata[ 7:0], 24'b0 };
    wire [31:0] sh_wdata = mem_offset[1] ? {rs2_rdata[15:0], 16'b0}
                                         : {16'b0, rs2_rdata[15:0]};

    assign o_dmem_wdata = (funct3[1:0] == 2'b00) ? sb_wdata :
                          (funct3[1:0] == 2'b01) ? sh_wdata :
                                                   rs2_rdata;   // word

    // --- Sign/zero extension for loads ---
    wire [31:0] dmem_ext;
    sign_zero_ext sext (
        .i_dmem_rdata (i_dmem_rdata),
        .i_funct3     (funct3),
        .i_byte_offset(mem_offset),
        .o_dmem_ext   (dmem_ext)
    );

    assign rd_wdata =
        ctrl_i_type_lui         ? immediate     :   // LUI
        ctrl_i_type_unsigned    ? pc_plus_imm   :   // AUIPC
        ctrl_i_type_jmp         ? pc_plus_4     :   // JAL / JALR
        ctrl_mem_to_reg         ? i_dmem_rdata  :   // LOAD
        alu_result;                                 // ALU (R / I type)

endmodule

`default_nettype wire
