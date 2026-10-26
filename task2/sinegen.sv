module sinegen #(
    parameter WIDTH = 8
)(
    // interface signals
    input logic clk,
    input logic rst,
    input logic en,
    input  logic [WIDTH-1:0] incr, 
    output logic [WIDTH-1:0] dout1,
    output logic [WIDTH-1:0] dout2,
    input logic [WIDTH-1:0] offset,
    
);
    logic [WIDTH-1:0] addr;

    counter myCounter(
        .clk (clk),
        .rst (rst),
        .en (en),
        .incr (incr),
        .count (addr)

    );

    dualrom myDualRom (
        .clk (clk),
        .addr1 (addr),
        .addr2(addr + offset),
        .dout1 (dout1),
        .dout2 (dout2)
    );

endmodule
