module sinegen #(
    parameter WIDTH = 8
)(
    // interface signals
    input logic clk,
    input logic rst,
    input logic en,
    input  logic [WIDTH-1:0] incr, 
    output logic [WIDTH-1:0] dout
    
);
    logic [WIDTH-1:0] addr;

    counter myCounter(
        .clk (clk),
        .rst (rst),
        .en (en),
        .incr (incr),
        .count (addr)

    );

    rom myRom (
        .clk (clk),
        .addr(addr),
        .dout (dout)
    );

endmodule
