`ifndef IFETCH
`define IFETCH
module IFetch(
    input  wire              clk_in,
    input  wire              rst_in,
    input  wire              rdy_in,

    input  wire              io_buffer_full,

    input  wire [511:0]      memctrl_res,
    input  wire              memctrl_done,
    output reg               memctrl_todo,
    output reg  [ 31:0]      memctrl_addr,

    output reg               decoder_todo,
    output reg  [31:0]       decoder_inst,
    output wire [31:0]       decoder_pc,

    input  wire              rob_full,

    input  wire              rs_full,
    
    input  wire              lsb_full
);
    localparam IDLE = 0, PENDING = 1;
    reg status;
    reg [31:0] pc;

    reg [511:0] icache_data[15:0];
    reg [21:0] icache_tag[15:0];
    reg icache_valid[15:0];
    wire [31:0] icache_data_reg[15:0];
    genvar i;
    assign decoder_pc = pc;
    generate
        for (i = 0; i < 16; i = i + 1)
            assign icache_data_reg[i] = icache_data[pc[9:6]][i * 32 + 31 : i * 32];
    endgenerate

    integer j;
    always @(posedge clk_in) begin
        if (rst_in) begin
            status <= IDLE;
            pc <= 0;
            for (j = 0; j < 16; j = j + 1) icache_valid[j] <= 0;
        end
        else if (rdy_in) begin
            if (status == IDLE) begin
                if (icache_valid[pc[9:6]] && icache_tag[pc[9:6]] == pc[31:10]) begin
                    if (!rob_full && !rs_full && !lsb_full) begin
                        decoder_todo <= 1;
                        decoder_inst <= icache_data_reg[pc[5:2]];
                    end
                end
                else begin
                    status <= PENDING;
                    memctrl_todo <= 1;
                    memctrl_addr <= {pc[31:6], 6'b0};
                end
            end
            else if (memctrl_done) begin
                icache_data[memctrl_addr[9:6]] <= memctrl_res;
                icache_tag[memctrl_addr[9:6]] <= memctrl_addr[31:10];
                icache_valid[memctrl_addr[9:6]] <= 1;
                status <= IDLE;
                memctrl_todo <= 0;
            end
        end
    end
endmodule
`endif