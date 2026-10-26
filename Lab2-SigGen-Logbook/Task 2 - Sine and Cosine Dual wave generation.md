- Goal: Generate two sinusoids at once with a phase difference (offset) set by the Vbuddy rotary encoder `vbdValue()`
- Note that an offset of 64 gives a 90 degree offset (producing sine and cosine). These are called quadrature signals - used in communication systems
- This is because the table is 256 entries which is defined as a full cycle. 360/256 = one entry meaning that phase difference = offset x 360/256
# Dual Port ROM
- We use the same `sinemem.rom` as in [[Task 1 - Simple sinewave generator]] but this time we have two read ports. Each port has its own address and its own output, and both read on the clock edge
- The port 1 address comes from the counter as in [[Task 1 - Simple sinewave generator]] and the port 2 address `= addr1 + offset` where `offset` is set by `vbdValue()` 
- The counter step `incr` stays at 1 so both waves have the same frequency and we can clearly see the phase difference

# Rom.sv
 ```verilog
 	 module dualrom #(
    parameter ADDRESS_WIDTH = 8,
    parameter DATA_WIDTH    = 8
)(
    input  logic                     clk,
    input  logic [ADDRESS_WIDTH-1:0] addr1,
    input  logic [ADDRESS_WIDTH-1:0] addr2,
    output logic [DATA_WIDTH-1:0]    dout1,
    output logic [DATA_WIDTH-1:0]    dout2,
);

    logic [DATA_WIDTH-1:0] rom_array [2**ADDRESS_WIDTH-1:0];

    initial begin
        $display("Loading rom.");
        $readmemh("sinerom.mem", rom_array);
    end
   
    always_ff @(posedge clk) begin
        // output is synchronous
        dout1 <= rom_array[addr1];
        dout2 <= rom_array[addr2];
        end
endmodule
 ```

# Sinegen.sv
```verilog 
module sinegen #(
    parameter WIDTH = 8
)(
    // interface signals
    input logic clk,
    input logic rst,
    input logic en,
    input  logic [WIDTH-1:0] incr,
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
```

# Sinegen_tb.cpp
```cpp
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Vsinegen.h"
#include "vbuddy.cpp"     // include vbuddy code
#define MAX_SIM_CYC 1000000
#define ADDRESS_WIDTH 8
#define ROM_SZ 256

int main(int argc, char **argv, char **env) {
  int simcyc;     // simulation clock count
  int tick;       // each clk cycle has two ticks for two edges

  Verilated::commandArgs(argc, argv);
  // init top verilog instance
  Vsinegen* top = new Vsinegen;
  // init trace dump
  Verilated::traceEverOn(true);
  VerilatedVcdC* tfp = new VerilatedVcdC;
  top->trace (tfp, 99);
  tfp->open ("sinegen.vcd");
  // init Vbuddy
  if (vbdOpen()!=1) return(-1);
  vbdHeader("L2T2: SigGen");
  //vbdSetMode(1);        // Flag mode set to one-shot
  // initialize simulation inputs
  top->clk = 1;
  top->rst = 0;
  top->en = 1;
  top->incr = 1;
  top->offset = 0;

  // run simulation for MAX_SIM_CYC clock cycles
  for (simcyc=0; simcyc<MAX_SIM_CYC; simcyc++) {
    // dump variables into VCD file and toggle clock
    for (tick=0; tick<2; tick++) {
      tfp->dump (2*simcyc+tick);
      top->clk = !top->clk;
      top->eval ();
    }
    top->offset = vbdValue();
    // plot ROM output and print cycle count
    vbdPlot(int (top->dout1), 0, 255);
    vbdPlot(int (top->dout2), 0, 255);
    vbdCycle(simcyc);

    // either simulation finished, or 'q' is pressed
    if ((Verilated::gotFinish()) || (vbdGetkey()=='q'))
      exit(0);                // ... exit if finish OR 'q' pressed
  }
  vbdClose();     // ++++
  tfp->close();
  exit(0);

}
```
