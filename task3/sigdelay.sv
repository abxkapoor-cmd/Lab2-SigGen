module sigdelay #(
    parameter ADDRESS_WIDTH = 9,
    parameter DATA_WIDTH = 8
)(
    input logic clk,
    input logic rst,
    input logic en,
    input logic wr,
    input logic rd,
    input logic [DATA_WIDTH-1:0] mic_signal,
    input logic [ADDRESS_WIDTH-1:0] offset,
    output logic [DATA_WIDTH-1:0] delayed_signal
);
    logic [ADDRESS_WIDTH-1:0] wr_addr;
    logic [ADDRESS_WIDTH-1:0] rd_addr;

    assign rd_addr = wr_addr - offset;

    counter #(.WIDTH(ADDRESS_WIDTH)) myCounter (
        .clk (clk),
        .rst (rst),
        .en (en),
        .incr ({{ADDRESS_WIDTH-1{1'b0}}, 1'b1}),
        .count(wr_addr)
    );

    ram2ports #(
        .ADDRESS_WIDTH (ADDRESS_WIDTH),
        .DATA_WIDTH    (DATA_WIDTH)
    ) myRam (
        .clk     (clk),
        .wr_en   (1'b1),
        .rd_en   (1'b1),
        .wr_addr (wr_addr),
        .rd_addr (rd_addr),
        .din     (mic_signal),
        .dout    (delayed_signal)
    );

endmodule
