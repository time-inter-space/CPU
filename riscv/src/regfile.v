`ifndef REGFILE
`define REGFILE
module RegFile(
    input  wire              clk_in,
    input  wire              rst_in,
    input  wire              rdy_in,

    input  wire              io_buffer_full,

    input  wire              issue,
    input  wire [4:0]        issue_rd,
    input  wire [4:0]        issue_rename,

    input  wire              commit,
    input  wire [ 4:0]       commit_rd,
    input  wire [31:0]       commit_val,
    input  wire [ 4:0]       commit_rename,

    input  wire [4:0]        rs1,
    output reg [31:0]        val1,
    output reg  [4:0]        rename1,
    input  wire [4:0]        rs2,
    output reg [31:0]        val2,
    output reg  [4:0]        rename2
);
    reg ready[31:0];
    reg [31:0] val[31:0];
    reg [4:0] rename[31:0];

    integer i;
    always @(posedge clk_in) begin
        if (rst_in) begin
            for (i = 0; i < 32; i = i + 1) begin
                ready[i] <= 1;
                val[i] <= 0;
                rename[i] <= 5'b11111;
            end
        end
        else if (rdy_in) begin
            if (commit && commit_rd != 0) begin
                ready[commit_rd] <= 1;
                if (rename[commit_rd] == commit_rename) begin
                    val[commit_rd] <= commit_val;
                    rename[commit_rd] <= 5'b11111;
                end
            end
            if (issue && issue_rd != 0) begin
                ready[issue_rd] <= 0;
                rename[issue_rd] <= issue_rename;
            end
        end
    end

    always @(*) begin
        if (commit && commit_rd != 0 && rs1 == commit_rd
            && rename[commit_rd] == commit_rename) begin
                val1 <= commit_val;
                rename1 <= 5'b11111;
            end
        else begin
            val1 <= val[rs1];
            rename1 <= rename[rs1];
        end
        if (commit && commit_rd != 0 && rs2 == commit_rd
            && rename[commit_rd] == commit_rename) begin
                val2 <= commit_val;
                rename2 <= 5'b11111;
            end
        else begin
            val2 <= val[rs2];
            rename2 <= rename[rs2];
        end
    end
endmodule
`endif