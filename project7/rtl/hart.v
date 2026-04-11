`default_nettype none

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
    // per cycle and sequentially returns a 32-bit instruction word. For
    // projects 6 and 7, this memory has been updated to be more realistic
    // - reads are no longer combinational, and both read and write accesses
    // take multiple cycles to complete.
    //
    // The testbench memory models a fixed, multi cycle memory with partial
    // pipelining. The memory will accept a new request every N cycles by
    // asserting `mem_ready`, and if a request is made, the memory perform
    // the request (read or write) after M cycles, asserting mem_valid to
    // indicate the read data is ready (or the write is complete). Requests
    // are completed in order. The values of N and M are deterministic, but
    // may change between test cases - you must design your CPU to work
    // correctly by looking at `mem_ready` and `mem_valid` rather than
    // hardcoding a latency assumption.
    //
    // Indicates that the memory is ready to accept a new read request.
    input  wire        i_imem_ready,
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Issue a read request to the memory on this cycle. This should not be
    // asserted if `i_imem_ready` is not asserted.
    output wire        o_imem_ren,
    // Indicates that a valid instruction word is being returned from memory.
    input  wire        i_imem_valid,
    // Instruction word fetched from memory, available sequentially some
    // M cycles after a request (imem_ren) is issued.
    input  wire [31:0] i_imem_rdata,

    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle.
    //
    // The timing of the dmem interface is the same as the imem interface. See
    // the documentation above.
    //
    // Indicates that the memory is ready to accept a new read or write request.
    input  wire        i_dmem_ready,
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
    // address. It is illegal to assert this and `o_dmem_ren` on the same
    // cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // the processor supports byte and half-word loads and stores at unaligned
    // and 16-bit aligned addresses, respectively. To support this, the access
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
    // Indicates that a valid data word is being returned from memory.
    input  wire        i_dmem_valid,
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
    output wire [31:0] o_retire_dmem_addr,
    output wire [ 3:0] o_retire_dmem_mask,
    output wire        o_retire_dmem_ren,
    output wire        o_retire_dmem_wen,
    output wire [31:0] o_retire_dmem_rdata,
    output wire [31:0] o_retire_dmem_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc
);
    // =========================================================================
    // STALL / FLUSHES (also includes early declarations for compilation)
    // =========================================================================
    wire hdu_stall;
    wire dmem_stall;
    wire fetch_stall;
    wire flush;
    reg [31:0] EX_MEM_alu_result;
    reg [31:0] EX_MEM_pc_plus_4;
    reg [31:0] EX_MEM_pc_plus_imm;
    reg [31:0] EX_MEM_immediate;
    reg [4:0] MEM_WB_rd_waddr;
    reg [4:0] EX_MEM_rd_waddr;
    reg EX_MEM_ctrl_i_type_jmp;
    reg EX_MEM_ctrl_i_type_lui;
    reg EX_MEM_ctrl_i_type_unsigned;
    reg MEM_WB_ctrl_rd_wen;
    reg EX_MEM_ctrl_rd_wen;
    reg EX_MEM_valid;
    reg EX_MEM_ctrl_dmem_ren;
    reg EX_MEM_ctrl_dmem_wen;

    // Cache interface wires (driven/used below; caches instantiated at bottom)
    wire        icache_busy;
    wire [31:0] icache_res_rdata;
    wire        dcache_busy;
    wire [31:0] dcache_res_rdata;
    // CPU-side dmem request wires (driven by MEM stage, consumed by dcache)
    wire [31:0] cpu_dmem_addr;
    wire        cpu_dmem_ren;
    wire        cpu_dmem_wen;
    wire [ 3:0] cpu_dmem_mask;
    wire [31:0] cpu_dmem_wdata;

    // =========================================================================
    // PROGRAM COUNTER
    // =========================================================================
    reg [31:0] pc;
    wire [31:0] next_pc;
    wire[31:0] pc_plus_4;

    assign pc_plus_4 = pc + 32'd4;

    always @(posedge i_clk) begin
        if (i_rst)
            pc <= RESET_ADDR;
        else if (flush)
            pc <= next_pc;
        else if (!icache_busy && !fetch_stall)
            pc <= pc + 32'd4;
    end

    // =========================================================================
    // INSTRUCTION FETCH (INSTRUCTION CACHE)
    // =========================================================================
    cache icache (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .i_mem_ready(i_imem_ready),
        .o_mem_addr (o_imem_raddr),
        .o_mem_ren  (o_imem_ren),
        .o_mem_wen  (/* unused: icache never writes */),
        .o_mem_wdata(/* unused: icache never writes */),
        .i_mem_rdata(i_imem_rdata),
        .i_mem_valid(i_imem_valid),
        .o_busy     (icache_busy),
        .i_req_addr (pc),
        .i_req_ren  (1'b1),
        .i_req_wen  (1'b0),
        .i_req_mask (4'b1111),
        .i_req_wdata(32'b0),
        .o_res_rdata(icache_res_rdata)
    );

    // =========================================================================
    // IF/ID Pipeline Register
    // =========================================================================
    reg IF_ID_valid;
    reg [31:0] IF_ID_pc;
    reg [31:0] IF_ID_instruction;
    reg [31:0] IF_ID_pc_plus_4;

    always @(posedge i_clk) begin
        if (i_rst | flush) begin
            IF_ID_valid <= 1'b0;
            IF_ID_pc <= RESET_ADDR;
            IF_ID_instruction <= 32'b0;
            IF_ID_pc_plus_4 <= RESET_ADDR;
        end else if (fetch_stall) begin
            // hold IF/ID contents while the pipeline is stalled downstream
        end else if (!icache_busy) begin
            IF_ID_valid <= 1'b1;
            IF_ID_pc <= pc;
            IF_ID_instruction <= icache_res_rdata;
            IF_ID_pc_plus_4 <= pc + 32'd4;
        end else begin
            // icache miss: insert a bubble while waiting for the fill
            IF_ID_valid <= 1'b0;
        end
    end

    // =========================================================================
    // DECODE LOGIC
    // =========================================================================
    // Control unit wires
    wire [5:0] ctrl_imm_fmt;
    wire ctrl_rd_wen;
    wire ctrl_i_type_lui;
    wire ctrl_i_type_unsigned;
    wire ctrl_alu_imm;
    wire ctrl_dmem_ren;
    wire ctrl_dmem_wen;
    wire ctrl_mem_to_reg;
    wire ctrl_branch_en;
    wire ctrl_jump_sel;
    wire ctrl_i_type_jmp;

    control ctrl_unit(
        .i_opcode    (IF_ID_instruction[6:0]),
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
        .i_inst     (IF_ID_instruction),
        .i_format   (ctrl_imm_fmt),
        .o_immediate(immediate)
    );

    // =========================================================================
    // REGFILE
    // =========================================================================
    wire [31:0] rs1_rdata;
    wire [31:0] rs2_rdata;
    wire        wb_rd_wen;
    wire [31:0] wb_rd_wdata;

    rf #(.BYPASS_EN(1)) regfile (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .i_rs1_raddr(IF_ID_instruction[19:15]),
        .o_rs1_rdata(rs1_rdata),
        .i_rs2_raddr(IF_ID_instruction[24:20]),
        .o_rs2_rdata(rs2_rdata),
        .i_rd_wen   (wb_rd_wen),
        .i_rd_waddr (MEM_WB_rd_waddr),
        .i_rd_wdata (wb_rd_wdata)
    );

    // =========================================================================
    // ID/EX Pipeline Register
    // =========================================================================
    // data signals
    reg [31:0] ID_EX_pc;
    reg [31:0] ID_EX_instruction;
    reg [31:0] ID_EX_pc_plus_4;
    reg [31:0] ID_EX_rs1_rdata;
    reg [31:0] ID_EX_rs2_rdata;
    reg [31:0] ID_EX_immediate;
    reg [4:0] ID_EX_rs1_raddr;
    reg [4:0] ID_EX_rs2_raddr;
    reg [4:0] ID_EX_rd_waddr;

    // control signals
    reg ID_EX_valid;
    reg ID_EX_ctrl_rd_wen;
    reg ID_EX_ctrl_i_type_lui;
    reg ID_EX_ctrl_i_type_unsigned;
    reg ID_EX_ctrl_alu_imm;
    reg ID_EX_ctrl_dmem_ren;
    reg ID_EX_ctrl_dmem_wen;
    reg ID_EX_ctrl_mem_to_reg;
    reg ID_EX_ctrl_branch_en;
    reg ID_EX_ctrl_jump_sel;
    reg ID_EX_ctrl_i_type_jmp;

    always @(posedge i_clk) begin
        if (i_rst) begin
            ID_EX_valid <= 1'b0;
            ID_EX_pc <= RESET_ADDR;
            ID_EX_instruction <= 32'b0;
            ID_EX_pc_plus_4 <= RESET_ADDR;
            ID_EX_rs1_rdata <= 32'b0;
            ID_EX_rs2_rdata <= 32'b0;
            ID_EX_immediate <= 32'b0;
            ID_EX_rs1_raddr <= 5'b0;
            ID_EX_rs2_raddr <= 5'b0;
            ID_EX_rd_waddr <= 5'b0;
            ID_EX_ctrl_rd_wen <= 1'b0;
            ID_EX_ctrl_i_type_lui <= 1'b0;
            ID_EX_ctrl_i_type_unsigned <= 1'b0;
            ID_EX_ctrl_alu_imm <= 1'b0;
            ID_EX_ctrl_dmem_ren <= 1'b0;
            ID_EX_ctrl_dmem_wen <= 1'b0;
            ID_EX_ctrl_mem_to_reg <= 1'b0;
            ID_EX_ctrl_branch_en <= 1'b0;
            ID_EX_ctrl_jump_sel <= 1'b0;
            ID_EX_ctrl_i_type_jmp <= 1'b0;
        end else if (dmem_stall) begin
            // hold on dmem stall
        end else if (flush | hdu_stall) begin
            ID_EX_valid <= 1'b0;
            ID_EX_ctrl_rd_wen <= 1'b0;
            ID_EX_ctrl_i_type_lui <= 1'b0;
            ID_EX_ctrl_i_type_unsigned <= 1'b0;
            ID_EX_ctrl_alu_imm <= 1'b0;
            ID_EX_ctrl_dmem_ren <= 1'b0;
            ID_EX_ctrl_dmem_wen <= 1'b0;
            ID_EX_ctrl_mem_to_reg <= 1'b0;
            ID_EX_ctrl_branch_en <= 1'b0;
            ID_EX_ctrl_jump_sel <= 1'b0;
            ID_EX_ctrl_i_type_jmp <= 1'b0;
        end else begin
            ID_EX_valid <= IF_ID_valid;
            ID_EX_pc <= IF_ID_pc;
            ID_EX_instruction <= IF_ID_instruction;
            ID_EX_pc_plus_4 <= IF_ID_pc_plus_4;
            ID_EX_rs1_rdata <= rs1_rdata;
            ID_EX_rs2_rdata <= rs2_rdata;
            ID_EX_immediate <= immediate;
            ID_EX_rs1_raddr <= IF_ID_instruction[19:15];
            ID_EX_rs2_raddr <= IF_ID_instruction[24:20];
            ID_EX_rd_waddr <= IF_ID_instruction[11:7];
            ID_EX_ctrl_rd_wen <= IF_ID_valid && ctrl_rd_wen;
            ID_EX_ctrl_i_type_lui <= IF_ID_valid && ctrl_i_type_lui;
            ID_EX_ctrl_i_type_unsigned <= IF_ID_valid && ctrl_i_type_unsigned;
            ID_EX_ctrl_alu_imm <= IF_ID_valid && ctrl_alu_imm;
            ID_EX_ctrl_dmem_ren <= IF_ID_valid && ctrl_dmem_ren;
            ID_EX_ctrl_dmem_wen <= IF_ID_valid && ctrl_dmem_wen;
            ID_EX_ctrl_mem_to_reg <= IF_ID_valid && ctrl_mem_to_reg;
            ID_EX_ctrl_branch_en <= IF_ID_valid && ctrl_branch_en;
            ID_EX_ctrl_jump_sel <= IF_ID_valid && ctrl_jump_sel;
            ID_EX_ctrl_i_type_jmp <= IF_ID_valid && ctrl_i_type_jmp;
        end
    end
        
    // =========================================================================
    // HAZARD DETECTION UNIT
    // =========================================================================
    hdu hdu_inst (
        .i_id_rs1     (IF_ID_instruction[19:15]),
        .i_id_rs2     (IF_ID_instruction[24:20]),
        .i_ex_rd_wen  (ID_EX_valid && ID_EX_ctrl_rd_wen),
        .i_ex_rd_waddr(ID_EX_rd_waddr),
        .i_ex_dmem_ren(ID_EX_valid && ID_EX_ctrl_dmem_ren),
        .o_stall      (hdu_stall)
    );

    assign dmem_stall     = dcache_busy;
    assign fetch_stall = hdu_stall | dmem_stall;

    // =========================================================================
    // FORWARDING UNIT
    // =========================================================================
    wire [1:0] fwd_rs1_sel;
    wire [1:0] fwd_rs2_sel;

    fwdu fwdu_inst (
        .i_ex_rs1_raddr(ID_EX_rs1_raddr),
        .i_ex_rs2_raddr(ID_EX_rs2_raddr),
        .i_mem_rd_wen  (EX_MEM_valid && EX_MEM_ctrl_rd_wen),
        .i_mem_rd_waddr(EX_MEM_rd_waddr),
        .i_wb_rd_wen   (wb_rd_wen),
        .i_wb_rd_waddr (MEM_WB_rd_waddr),
        .o_fwd_rs1_sel (fwd_rs1_sel),
        .o_fwd_rs2_sel (fwd_rs2_sel)
    );

    // EX stage result
    wire [31:0] ex_stage_mux_jmp;
    wire [31:0] ex_stage_mux_lui;
    wire [31:0] ex_stage_fwd_data;

    assign ex_stage_mux_jmp  = EX_MEM_ctrl_i_type_jmp ? EX_MEM_pc_plus_4 : EX_MEM_alu_result;
    assign ex_stage_mux_lui  = EX_MEM_ctrl_i_type_lui ? EX_MEM_immediate : EX_MEM_pc_plus_imm;
    assign ex_stage_fwd_data = EX_MEM_ctrl_i_type_unsigned ? ex_stage_mux_lui : ex_stage_mux_jmp;

    // =========================================================================
    // ALU / EXECUTE LOGIC
    // =========================================================================
    wire [31:0] alu_result;
    wire [31:0] alu_op1;
    wire [31:0] alu_op2;
    wire [31:0] fwd_rs2_data;
    wire alu_eq;
    wire alu_slt;

    // MEM-EX forwarding feeds the rd_wdata
    assign alu_op1 = (fwd_rs1_sel == 2'b01) ? ex_stage_fwd_data :
                     (fwd_rs1_sel == 2'b10) ? wb_rd_wdata :
                                        ID_EX_rs1_rdata;

    assign fwd_rs2_data = (fwd_rs2_sel == 2'b01) ? ex_stage_fwd_data :
                          (fwd_rs2_sel == 2'b10) ? wb_rd_wdata :
                                             ID_EX_rs2_rdata;

    assign alu_op2 = ID_EX_ctrl_alu_imm ? ID_EX_immediate : fwd_rs2_data;

    alu alu_inst (
        .i_opsel   ((ID_EX_ctrl_dmem_ren | ID_EX_ctrl_dmem_wen) ? 3'b000 : ID_EX_instruction[14:12]),
        .i_sub     (~ID_EX_ctrl_alu_imm & ID_EX_instruction[30]),
        .i_unsigned(ID_EX_instruction[12]),
        .i_arith   (ID_EX_instruction[30]),
        .i_op1     (alu_op1),
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
        .i_funct3   (ID_EX_instruction[14:12]),
        .i_eq       (alu_eq),
        .i_slt      (alu_slt),
        .i_branch_en(ID_EX_ctrl_branch_en),
        .o_branch   (branch_result)
    );

    // flush on jump or branch
    assign flush = ID_EX_valid && (ID_EX_ctrl_i_type_jmp | branch_result) && ~dmem_stall;

    // =========================================================================
    // UPDATE PC LOGIC / JUMP LOGIC
    // =========================================================================
    wire [31:0] pc_plus_imm;
    assign pc_plus_imm = ID_EX_pc + ID_EX_immediate;

    wire [31:0] jalr_target;
    assign jalr_target = alu_result & 32'hfffffffe;

    wire [31:0] mux_jump_select;
    assign mux_jump_select = ID_EX_ctrl_jump_sel ? pc_plus_imm : jalr_target;

    wire [31:0] mux_pc_plus_4_or_branch;
    assign mux_pc_plus_4_or_branch = branch_result ? pc_plus_imm : pc_plus_4;

    assign next_pc = ID_EX_ctrl_i_type_jmp ? mux_jump_select : mux_pc_plus_4_or_branch;

    // =========================================================================
    // EX/MEM Pipeline Register
    // =========================================================================
    // data signals
    reg [31:0] EX_MEM_pc;
    reg [31:0] EX_MEM_instruction;
    reg [31:0] EX_MEM_next_pc;
    reg [31:0] EX_MEM_rs2_rdata;
    reg [31:0] EX_MEM_rs1_rdata;
    reg [4:0] EX_MEM_rs1_raddr;
    reg [4:0] EX_MEM_rs2_raddr;

    // control signals
    reg EX_MEM_ctrl_mem_to_reg;

    always @(posedge i_clk) begin
        if (i_rst) begin
            EX_MEM_pc <= RESET_ADDR;
            EX_MEM_instruction <= 32'b0;
            EX_MEM_pc_plus_4 <= RESET_ADDR;
            EX_MEM_pc_plus_imm <= 32'b0;
            EX_MEM_next_pc <= RESET_ADDR;
            EX_MEM_immediate <= 32'b0;
            EX_MEM_alu_result <= 32'b0;
            EX_MEM_rs2_rdata <= 32'b0;
            EX_MEM_rs1_rdata <= 32'b0;
            EX_MEM_rs1_raddr <= 5'b0;
            EX_MEM_rs2_raddr <= 5'b0;
            EX_MEM_rd_waddr <= 5'b0;
            EX_MEM_valid <= 1'b0;
            EX_MEM_ctrl_rd_wen <= 1'b0;
            EX_MEM_ctrl_dmem_ren <= 1'b0;
            EX_MEM_ctrl_dmem_wen <= 1'b0;
            EX_MEM_ctrl_mem_to_reg <= 1'b0;
            EX_MEM_ctrl_i_type_jmp <= 1'b0;
            EX_MEM_ctrl_i_type_lui <= 1'b0;
            EX_MEM_ctrl_i_type_unsigned <= 1'b0;
        end else if (!dmem_stall) begin
            EX_MEM_pc <= ID_EX_pc;
            EX_MEM_instruction <= ID_EX_instruction;
            EX_MEM_pc_plus_4 <= ID_EX_pc_plus_4;
            EX_MEM_pc_plus_imm <= pc_plus_imm;
            EX_MEM_next_pc <= next_pc;
            EX_MEM_immediate <= ID_EX_immediate;
            EX_MEM_alu_result <= alu_result;
            EX_MEM_rs2_rdata <= fwd_rs2_data;
            EX_MEM_rs1_rdata <= alu_op1;
            EX_MEM_rs1_raddr <= ID_EX_rs1_raddr;
            EX_MEM_rs2_raddr <= ID_EX_rs2_raddr;
            EX_MEM_rd_waddr <= ID_EX_rd_waddr;
            EX_MEM_valid <= ID_EX_valid;
            EX_MEM_ctrl_rd_wen <= ID_EX_ctrl_rd_wen;
            EX_MEM_ctrl_dmem_ren <= ID_EX_ctrl_dmem_ren;
            EX_MEM_ctrl_dmem_wen <= ID_EX_ctrl_dmem_wen;
            EX_MEM_ctrl_mem_to_reg <= ID_EX_ctrl_mem_to_reg;
            EX_MEM_ctrl_i_type_jmp <= ID_EX_ctrl_i_type_jmp;
            EX_MEM_ctrl_i_type_lui <= ID_EX_ctrl_i_type_lui;
            EX_MEM_ctrl_i_type_unsigned <= ID_EX_ctrl_i_type_unsigned;
        end
    end

    // =========================================================================
    // DATA CACHE
    // =========================================================================
    cache dcache (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .i_mem_ready(i_dmem_ready),
        .o_mem_addr (o_dmem_addr),
        .o_mem_ren  (o_dmem_ren),
        .o_mem_wen  (o_dmem_wen),
        .o_mem_wdata(o_dmem_wdata),
        .i_mem_rdata(i_dmem_rdata),
        .i_mem_valid(i_dmem_valid),
        .o_busy     (dcache_busy),
        .i_req_addr (cpu_dmem_addr),
        .i_req_ren  (cpu_dmem_ren),
        .i_req_wen  (cpu_dmem_wen),
        .i_req_mask (cpu_dmem_mask),
        .i_req_wdata(cpu_dmem_wdata),
        .o_res_rdata(dcache_res_rdata)
    );

    // =========================================================================
    // MEMORY LOGIC (data cache)
    // =========================================================================
    wire [1:0] mem_offset = EX_MEM_alu_result[1:0];

    assign cpu_dmem_addr = {EX_MEM_alu_result[31:2], 2'b00};
    assign cpu_dmem_ren  = EX_MEM_ctrl_dmem_ren & EX_MEM_valid;
    assign cpu_dmem_wen  = EX_MEM_ctrl_dmem_wen & EX_MEM_valid;

    wire [3:0] byte_mask = (mem_offset == 2'b00) ? 4'b0001 :
                           (mem_offset == 2'b01) ? 4'b0010 :
                           (mem_offset == 2'b10) ? 4'b0100 :
                                                   4'b1000;
    wire [3:0] half_mask = mem_offset[1] ? 4'b1100 : 4'b0011;

    assign cpu_dmem_mask = (EX_MEM_instruction[13:12] == 2'b00) ? byte_mask :
                           (EX_MEM_instruction[13:12] == 2'b01) ? half_mask :
                                                                  4'b1111;

    wire [31:0] sb_wdata = (mem_offset == 2'b00) ? {24'b0, EX_MEM_rs2_rdata[ 7:0]        } :
                           (mem_offset == 2'b01) ? {16'b0, EX_MEM_rs2_rdata[ 7:0],  8'b0 } :
                           (mem_offset == 2'b10) ? { 8'b0, EX_MEM_rs2_rdata[ 7:0], 16'b0 } :
                                                   {       EX_MEM_rs2_rdata[ 7:0], 24'b0 };
    wire [31:0] sh_wdata = mem_offset[1] ? {EX_MEM_rs2_rdata[15:0], 16'b0}
                                         : EX_MEM_rs2_rdata;

    assign cpu_dmem_wdata = (EX_MEM_instruction[13:12] == 2'b00) ? sb_wdata :
                            (EX_MEM_instruction[13:12] == 2'b01) ? sh_wdata :
                                                                   EX_MEM_rs2_rdata;

    assign o_dmem_mask = 4'b1111;

    // Sign/zero extension module reads from the cache's response data.
    wire [31:0] dmem_ext;
    sign_zero_ext sext (
        .i_dmem_rdata (dcache_res_rdata),
        .i_funct3     (EX_MEM_instruction[14:12]),
        .i_byte_offset(mem_offset),
        .o_dmem_ext   (dmem_ext)
    );

    // =========================================================================
    // MEM/WB Pipeline Register
    // =========================================================================
    // data signals
    reg [31:0] MEM_WB_pc;
    reg [31:0] MEM_WB_instruction;
    reg [31:0] MEM_WB_pc_plus_4;
    reg [31:0] MEM_WB_pc_plus_imm;
    reg [31:0] MEM_WB_next_pc;
    reg [31:0] MEM_WB_immediate;
    reg [31:0] MEM_WB_alu_result;
    reg [31:0] MEM_WB_dmem_ext;
    reg [31:0] MEM_WB_rs1_rdata;
    reg [31:0] MEM_WB_rs2_rdata;  
    reg [4:0] MEM_WB_rs1_raddr;
    reg [4:0] MEM_WB_rs2_raddr;

    // control signals
    reg MEM_WB_valid;
    reg MEM_WB_ctrl_mem_to_reg;
    reg MEM_WB_ctrl_i_type_jmp;
    reg MEM_WB_ctrl_i_type_lui;
    reg MEM_WB_ctrl_i_type_unsigned;
    reg MEM_WB_ctrl_dmem_ren;
    reg MEM_WB_ctrl_dmem_wen;

    // dmem retire signals
    reg [31:0] MEM_WB_dmem_addr;
    reg [31:0] MEM_WB_dmem_wdata;
    reg [31:0] MEM_WB_dmem_rdata;
    reg [3:0] MEM_WB_dmem_mask;
    reg retire_valid_r;

    always @(posedge i_clk) begin
        if (i_rst) begin
            MEM_WB_pc <= RESET_ADDR;
            MEM_WB_instruction <= 32'b0;
            MEM_WB_pc_plus_4 <= RESET_ADDR;
            MEM_WB_pc_plus_imm <= 32'b0;
            MEM_WB_next_pc <= RESET_ADDR;
            MEM_WB_immediate <= 32'b0;
            MEM_WB_alu_result <= 32'b0;
            MEM_WB_dmem_ext <= 32'b0;
            MEM_WB_rs1_rdata <= 32'b0;
            MEM_WB_rs2_rdata <= 32'b0;
            MEM_WB_rs1_raddr <= 5'b0;
            MEM_WB_rs2_raddr <= 5'b0;
            MEM_WB_rd_waddr <= 5'b0;
            MEM_WB_valid <= 1'b0;
            MEM_WB_ctrl_rd_wen <= 1'b0;
            MEM_WB_ctrl_mem_to_reg <= 1'b0;
            MEM_WB_ctrl_i_type_jmp <= 1'b0;
            MEM_WB_ctrl_i_type_lui <= 1'b0;
            MEM_WB_ctrl_i_type_unsigned <= 1'b0;
            MEM_WB_ctrl_dmem_ren <= 1'b0;
            MEM_WB_ctrl_dmem_wen <= 1'b0;
            MEM_WB_dmem_addr <= 32'b0;
            MEM_WB_dmem_mask <= 4'b0;
            MEM_WB_dmem_wdata <= 32'b0;
            MEM_WB_dmem_rdata <= 32'b0;
            retire_valid_r <= 1'b0;
        end else if (!dmem_stall) begin
            MEM_WB_pc <= EX_MEM_pc;
            MEM_WB_instruction <= EX_MEM_instruction;
            MEM_WB_pc_plus_4 <= EX_MEM_pc_plus_4;
            MEM_WB_pc_plus_imm <= EX_MEM_pc_plus_imm;
            MEM_WB_next_pc <= EX_MEM_next_pc;
            MEM_WB_immediate <= EX_MEM_immediate;
            MEM_WB_alu_result <= EX_MEM_alu_result;
            MEM_WB_dmem_ext <= dmem_ext;
            MEM_WB_rs1_rdata <= EX_MEM_rs1_rdata;
            MEM_WB_rs2_rdata <= EX_MEM_rs2_rdata;
            MEM_WB_rs1_raddr <= EX_MEM_rs1_raddr;
            MEM_WB_rs2_raddr <= EX_MEM_rs2_raddr;
            MEM_WB_rd_waddr <= EX_MEM_rd_waddr;
            MEM_WB_valid <= EX_MEM_valid;
            MEM_WB_ctrl_rd_wen <= EX_MEM_ctrl_rd_wen;
            MEM_WB_ctrl_mem_to_reg <= EX_MEM_ctrl_mem_to_reg;
            MEM_WB_ctrl_i_type_jmp <= EX_MEM_ctrl_i_type_jmp;
            MEM_WB_ctrl_i_type_lui <= EX_MEM_ctrl_i_type_lui;
            MEM_WB_ctrl_i_type_unsigned <= EX_MEM_ctrl_i_type_unsigned;
            MEM_WB_ctrl_dmem_ren <= EX_MEM_ctrl_dmem_ren;
            MEM_WB_ctrl_dmem_wen <= EX_MEM_ctrl_dmem_wen;
            MEM_WB_dmem_addr <= cpu_dmem_addr;
            MEM_WB_dmem_mask <= cpu_dmem_mask;
            MEM_WB_dmem_wdata <= cpu_dmem_wdata;
            MEM_WB_dmem_rdata <= dcache_res_rdata;
            retire_valid_r <= EX_MEM_valid;
        end else begin
            retire_valid_r <= 1'b0;
        end
    end

    // =========================================================================
    // WRITEBACK LOGIC
    // =========================================================================
    wire [31:0] mux_mem_to_reg;
    assign mux_mem_to_reg = MEM_WB_ctrl_mem_to_reg ? MEM_WB_dmem_ext : MEM_WB_alu_result;

    wire [31:0] mux_jump_type;
    assign mux_jump_type = MEM_WB_ctrl_i_type_jmp ? MEM_WB_pc_plus_4 : mux_mem_to_reg;

    wire [31:0] mux_lui_en;
    assign mux_lui_en = MEM_WB_ctrl_i_type_lui ? MEM_WB_immediate : MEM_WB_pc_plus_imm;

    assign wb_rd_wdata = MEM_WB_ctrl_i_type_unsigned ? mux_lui_en : mux_jump_type;
    assign wb_rd_wen   = MEM_WB_valid && MEM_WB_ctrl_rd_wen;

    // =========================================================================
    // RETIRE INTERFACE
    // =========================================================================
    assign o_retire_valid = retire_valid_r;

    assign o_retire_inst = MEM_WB_instruction;

    assign o_retire_halt = (MEM_WB_instruction[6:0]   == 7'b1110011) &
                           (MEM_WB_instruction[14:12] == 3'b000) &
                           (MEM_WB_instruction[31:20] == 12'b000000000001);

    assign o_retire_trap = 1'b0;
    assign o_retire_rs1_raddr = MEM_WB_rs1_raddr;
    assign o_retire_rs1_rdata = MEM_WB_rs1_rdata;
    assign o_retire_rs2_raddr = MEM_WB_rs2_raddr;
    assign o_retire_rs2_rdata = MEM_WB_rs2_rdata;
    assign o_retire_rd_waddr = wb_rd_wen ? MEM_WB_rd_waddr : 5'd0;
    assign o_retire_rd_wdata = wb_rd_wdata;
    assign o_retire_pc = MEM_WB_pc;
    assign o_retire_next_pc = MEM_WB_next_pc;
    assign o_retire_dmem_addr = MEM_WB_dmem_addr;
    assign o_retire_dmem_ren = MEM_WB_ctrl_dmem_ren;
    assign o_retire_dmem_wen = MEM_WB_ctrl_dmem_wen;
    assign o_retire_dmem_mask = MEM_WB_dmem_mask;
    assign o_retire_dmem_wdata = MEM_WB_dmem_wdata;
    assign o_retire_dmem_rdata = MEM_WB_dmem_rdata;
endmodule

`default_nettype wire
