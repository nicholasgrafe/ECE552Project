`default_nettype none

module cache (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // External memory interface. See hart interface for details. This
    // interface is nearly identical to the phase 5 memory interface, with the
    // exception that the byte mask (`o_mem_mask`) has been removed. This is
    // no longer needed as the cache will only access the memory at word
    // granularity, and implement masking internally.
    input  wire        i_mem_ready,
    output wire [31:0] o_mem_addr,
    output wire        o_mem_ren,
    output wire        o_mem_wen,
    output wire [31:0] o_mem_wdata,
    input  wire [31:0] i_mem_rdata,
    input  wire        i_mem_valid,
    // Interface to CPU hart. This is nearly identical to the phase 5 hart memory
    // interface, but includes a stall signal (`o_busy`), and the input/output
    // polarities are swapped for obvious reasons.
    //
    // The CPU should use this as a stall signal for both instruction fetch
    // (IF) and memory (MEM) stages, from the instruction or data cache
    // respectively. If a memory request is made (`i_req_ren` for instruction
    // cache, or either `i_req_ren` or `i_req_wen` for data cache), this
    // should be asserted *combinationally* if the request results in a cache
    // miss.
    //
    // In case of a cache miss, the CPU must stall the respective pipeline
    // stage and deassert ren/wen on subsequent cycles, until the cache
    // deasserts `o_busy` to indicate it has serviced the cache miss. However,
    // the CPU must keep the other request lines constant. For example, the
    // CPU should not change the request address while stalling.
    output wire        o_busy,
    // 32-bit read/write address to access from the cache. This should be
    // 32-bit aligned (i.e. the two LSBs should be zero). See `i_req_mask` for
    // how to perform half-word and byte accesses to unaligned addresses.
    input  wire [31:0] i_req_addr,
    // When asserted, the cache should perform a read at the aligned address
    // specified by `i_req_addr` and return the 32-bit word at that address,
    // either immediately (i.e. combinationally) on a cache hit, or
    // synchronously on a cache miss. It is illegal to assert this and
    // `i_dmem_wen` on the same cycle.
    input  wire        i_req_ren,
    // When asserted, the cache should perform a write at the aligned address
    // specified by `i_req_addr` with the 32-bit word provided in
    // `o_req_wdata` (specified by the mask). This is necessarily synchronous,
    // but may either happen on the next clock edge (on a cache hit) or after
    // multiple cycles of latency (cache miss). As the cache is write-through
    // and write-allocate, writes must be applied to both the cache and
    // underlying memory.
    // It is illegal to assert this and `i_dmem_ren` on the same cycle.
    input  wire        i_req_wen,
    // The memory interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    input  wire [ 3:0] i_req_mask,
    // The 32-bit word to write to memory, if the request is a write
    // (i_req_wen is asserted). Only the bytes corresponding to set bits in
    // the mask should be written into the cache (and to backing memory).
    input  wire [31:0] i_req_wdata,
    // THe 32-bit data word read from memory on a read request.
    output wire [31:0] o_res_rdata
);
    // These parameters are equivalent to those provided in the project
    // 6 specification. Feel free to use them, but hardcoding these numbers
    // rather than using the localparams is also permitted, as long as the
    // same values are used (and consistent with the project specification).
    //
    // 32 sets * 2 ways per set * 16 bytes per way = 1K cache
    localparam O = 4;            // 4 bit offset => 16 byte cache line
    localparam S = 5;            // 5 bit set index => 32 sets
    localparam DEPTH = 32;       // 32 sets
    localparam W = 2;            // 2 way set associative, NMRU
    localparam T = 32 - O - S;   // 23 bit tag
    localparam D = 4;            // 16 bytes per line / 4 bytes per word = 4 words per line

    // The following memory arrays model the cache structure. As this is
    // an internal implementation detail, you are *free* to modify these
    // arrays as you please.

    // Backing memory, modeled as two separate ways.
    reg [   31:0] datas0 [DEPTH - 1:0][D - 1:0];
    reg [   31:0] datas1 [DEPTH - 1:0][D - 1:0];
    reg [T - 1:0] tags0  [DEPTH - 1:0];
    reg [T - 1:0] tags1  [DEPTH - 1:0];
    reg [DEPTH - 1:0] valid0;
    reg [DEPTH - 1:0] valid1;
    reg [DEPTH - 1:0] lru;

    // decode address to tag, index, and offset
    wire [T-1:0] req_tag   = i_req_addr[31 : O+S];
    wire [S-1:0] req_index = i_req_addr[O+S-1 : O  ];
    wire [1:0]   req_word  = i_req_addr[O-1 : 2  ];

    // check for hit in either set
    wire hit0 = valid0[req_index] && (tags0[req_index] == req_tag);
    wire hit1 = valid1[req_index] && (tags1[req_index] == req_tag);
    wire hit = hit0 | hit1;
    wire hit_way = hit1;

    // return value on read hit
    assign o_res_rdata = hit1 ? datas1[req_index][req_word]
                              : datas0[req_index][req_word];

    // cache replacement
    // fill invalid ways first, otherwise evict the least recently used line
    wire replace_way = !valid0[req_index] ? 1'b0 :
                       !valid1[req_index] ? 1'b1 :
                       lru[req_index];

    // CACHE STATES
    // S_IDLE: Handle read/write hits immediately; go to fill on miss
    // S_FILL: Fetch missing cache line from memory (write-allocate)
    // S_WT: Complete write after a miss by updating cache and memory (write through)
    localparam S_IDLE = 2'd0;
    localparam S_FILL = 2'd1;
    localparam S_WT   = 2'd2;
    reg [1:0] state;

    // original request info used while during cache miss or deferred write
    reg lat_wen;
    reg [3:0] lat_mask;
    reg [31:0] lat_wdata;
    reg lat_way;
    reg [T-1:0] lat_tag;
    reg [S-1:0] lat_index;
    reg [1:0] lat_word;

    // pipeline requests
    reg [2:0] fill_req_idx;
    reg [2:0] fill_resp_idx;

    wire req_active = i_req_ren | i_req_wen;
    wire read_hit_idle  = (state == S_IDLE) && i_req_ren && hit;
    wire write_hit_idle = (state == S_IDLE) && i_req_wen && hit;
    wire miss_idle = (state == S_IDLE) && req_active && !hit;
    assign o_busy = (state != S_IDLE) || miss_idle;

    // write-data merges: one using current request inputs for hits, and 
    // one using saved values for write-miss completion
    wire [31:0] req_mask_ext = {{8{i_req_mask[3]}}, {8{i_req_mask[2]}},
                                 {8{i_req_mask[1]}}, {8{i_req_mask[0]}}};

    wire [31:0] hit_cache_word = hit_way ? datas1[req_index][req_word]
                                         : datas0[req_index][req_word];

    wire [31:0] hit_merged = (hit_cache_word & ~req_mask_ext) |
                             (i_req_wdata & req_mask_ext);

    wire [31:0] lat_mask_ext = {{8{lat_mask[3]}}, {8{lat_mask[2]}},
                                 {8{lat_mask[1]}}, {8{lat_mask[0]}}};

    wire [31:0] lat_cache_word = lat_way ? datas1[lat_index][lat_word]
                                         : datas0[lat_index][lat_word];

    wire [31:0] lat_merged = (lat_cache_word & ~lat_mask_ext) |
                             (lat_wdata & lat_mask_ext);

    // Drive memory requests only when the memory is ready to accept them.
    assign o_mem_ren  = (state == S_FILL) && (fill_req_idx < 3'd4) && i_mem_ready;
    assign o_mem_wen  = ((state == S_WT) && i_mem_ready) || (write_hit_idle && i_mem_ready);
    assign o_mem_addr = (state == S_FILL) ? {lat_tag, lat_index, fill_req_idx[1:0], 2'b00}
                      : (state == S_WT) ? {lat_tag, lat_index, lat_word, 2'b00}
                      : write_hit_idle ? {i_req_addr[31:2], 2'b00}
                      : 32'h0;
    assign o_mem_wdata = (state == S_WT) ? lat_merged : hit_merged;

    // CACHE IMPLEMENTATION (sequential logic)
    always @(posedge i_clk) begin
        if (i_rst) begin
            state <= S_IDLE;
            fill_req_idx  <= 3'd0;
            fill_resp_idx <= 3'd0;
            valid0 <= {DEPTH{1'b0}};
            valid1 <= {DEPTH{1'b0}};
            lru    <= {DEPTH{1'b0}};
        end else begin
            case (state)
                S_IDLE: begin
                    if (miss_idle) begin
                        // cache miss
                        state <= S_FILL;
                        fill_req_idx  <= 3'd0;
                        fill_resp_idx <= 3'd0;
                        lat_wen <= i_req_wen;
                        lat_mask <= i_req_mask;
                        lat_wdata <= i_req_wdata;
                        lat_tag <= req_tag;
                        lat_index <= req_index;
                        lat_word <= req_word;
                        lat_way <= replace_way;
                    end else if (write_hit_idle) begin
                        // write hit (write through)
                        if (hit_way == 1'b0) begin
                            datas0[req_index][req_word] <= hit_merged;
                        end else begin
                            datas1[req_index][req_word] <= hit_merged;
                        end
                        lru[req_index] <= ~hit_way;
                    end else if (read_hit_idle) begin
                        lru[req_index] <= ~hit_way;
                    end
                end
                S_FILL: begin
                    // issue the next pipelined request when memory accepts it.
                    if (o_mem_ren) begin
                        fill_req_idx <= fill_req_idx + 3'd1;
                    end
                    // consume responses as they arrive (in order).
                    if (i_mem_valid) begin
                        if (lat_way == 1'b0) begin
                            datas0[lat_index][fill_resp_idx[1:0]] <= i_mem_rdata;
                        end else begin
                            datas1[lat_index][fill_resp_idx[1:0]] <= i_mem_rdata;
                        end
                        fill_resp_idx <= fill_resp_idx + 3'd1;
                        if (fill_resp_idx == 3'd3) begin
                            if (lat_way == 1'b0) begin
                                tags0[lat_index] <= lat_tag;
                                valid0[lat_index] <= 1'b1;
                            end else begin
                                tags1[lat_index] <= lat_tag;
                                valid1[lat_index] <= 1'b1;
                            end
                            lru[lat_index] <= ~lat_way;
                            state <= lat_wen ? S_WT : S_IDLE;
                        end
                    end
                end
                S_WT: begin
                    // wait for write-through and update cache for cache miss
                    if (i_mem_ready) begin
                        if (lat_way == 1'b0) begin
                            datas0[lat_index][lat_word] <= lat_merged;
                        end else begin
                            datas1[lat_index][lat_word] <= lat_merged;
                        end
                        state <= S_IDLE;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire
