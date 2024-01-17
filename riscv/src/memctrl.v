`ifndef MEMCTRL
`define MEMCTRL
module MemCtrl(
    input  wire              clk_in,
    input  wire              rst_in,
    input  wire              rdy_in,
    
    input  wire [ 7:0]       mem_din,
    output reg  [ 7:0]       mem_dout,
    output reg  [31:0]       mem_a,
    output reg               mem_wr,

    input  wire              io_buffer_full,

    output reg               memctrl_busy,

    input  wire              ifetch_todo,
    input  wire [ 31:0]      ifetch_addr,
    output wire [511:0]      ifetch_res,
    output reg               ifetch_done,

    input  wire              lsb_todo,
    input  wire [31:0]       lsb_addr,
    input  wire [ 2:0]       lsb_len,
    input  wire              lsb_store,
    input  wire [31:0]       store_data,
    output reg  [31:0]       load_res,
    output reg               lsb_done
);
    localparam IDLE = 0, IF = 1, LOAD = 2, STORE = 3;
    reg [1:0] status;
    integer cur;
    reg [7:0] ifetch_res_reg[63:0];
    genvar i;
    generate
        for (i = 0; i < 64; i = i + 1)
            assign ifetch_res[i * 8 + 7 : i * 8] = ifetch_res_reg[i];
    endgenerate
    always @(posedge clk_in) begin
        if (rst_in) begin
            status <= IDLE;
            memctrl_busy <= 0;
            mem_wr <= 0;
            ifetch_done <= 0;
            lsb_done <= 0;
        end
        else if (rdy_in) begin
            case (status)
            IDLE: begin
                ifetch_done <= 0;
                lsb_done <= 0;
                if (lsb_todo) begin
                    mem_a <= lsb_addr;
                    cur <= 0;
                    if (lsb_store) begin
                        status <= STORE;
                        memctrl_busy <= 1;
                        mem_wr <= 1;
                        mem_dout <= store_data[7:0];
                    end
                    else begin
                        status <= LOAD;
                        memctrl_busy <= 1;
                        mem_wr <= 0;
                        load_res <= 0;
                    end
                end
                else if (ifetch_todo) begin
                    status <= IF;
                    memctrl_busy <= 1;
                    mem_a <= ifetch_addr;
                    mem_wr <= 0;
                    cur <= 0;
                end
            end
            IF: begin
                ifetch_res_reg[cur] <= mem_din;
                if (cur == 63) begin
                    ifetch_done <= 1;
                    status <= IDLE;
                    memctrl_busy <= 0;
                    mem_wr <= 0;
                end
                else begin
                    cur <= cur + 1;
                    mem_a <= mem_a + 1;
                end
            end
            LOAD: begin
                case (cur)
                    0: load_res[ 7: 0] <= mem_din;
                    1: load_res[15: 8] <= mem_din;
                    2: load_res[23:16] <= mem_din;
                    3: load_res[31:24] <= mem_din;
                endcase
                if (cur + 1 == lsb_len) begin
                    lsb_done <= 1;
                    status <= IDLE;
                    memctrl_busy <= 0;
                    mem_wr <= 0;
                end
                else begin
                    cur <= cur + 1;
                    mem_a <= mem_a + 1;
                end
            end
            STORE: begin
                if (cur + 1 == lsb_len) begin
                    lsb_done <= 1;
                    status <= IDLE;
                    memctrl_busy <= 0;
                    mem_wr <= 0;
                end
                else begin
                    case (cur)
                        0: mem_dout <= store_data[15: 8];
                        1: mem_dout <= store_data[23:16];
                        2: mem_dout <= store_data[31:24];
                    endcase
                    cur <= cur + 1;
                    mem_a <= mem_a + 1;
                end
            end
            endcase
        end
    end
endmodule
`endif