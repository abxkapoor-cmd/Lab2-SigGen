- Goal: Capture real audio signal using the microphone/amplifier module on Vbuddy
- Samples are written to a dual-port RAM stored in successive locations
- We then read these samples from the other port of the RAM; the read address is offset from the write address and this offset is set by `vbdValue`which is no different from before
- Turning the rotary encoder therefore changes the offset which changes the time delay as the time delay is `= offset/sample rate`
- We use the `vbdInitMicIn()` function to inform Vbuddy the size of the audio signal bugger to reserve for storing a captured sample
- The microphone values are from the `vbdMicValue` function which returns the next sample in the audio buffer 
- When all samples are exhausted, Vbuddy automatically captures another block of audio samples and stores them in the audio buffer

# ram2ports.sv
```verilog 
module ram2ports #(
    parameter ADDRESS_WIDTH = 9,
    parameter DATA_WIDTH    = 8
)(
    input  logic                     clk,
    input  logic                     wr_en,
    input  logic                     rd_en,
    input  logic [ADDRESS_WIDTH-1:0] wr_addr,
    input  logic [ADDRESS_WIDTH-1:0] rd_addr,
    input  logic [DATA_WIDTH-1:0]    din,
    output logic [DATA_WIDTH-1:0]    dout
);
    logic [DATA_WIDTH-1:0] ram_array [2**ADDRESS_WIDTH-1:0];

    always_ff @(posedge clk) begin
        if (wr_en == 1'b1)
            ram_array[wr_addr] <= din;
        if (rd_en == 1'b1)
            // output is synchronous
            dout <= ram_array[rd_addr];
    end
endmodule
```
- This is a dual port RAM; it can write to one address and read from another in the same clock cycle

# sigdelay.sv
```verilog 
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
        .DATA_WIDTH    (DATA_WIDTH)
    ) myRam (
        .clk     (clk),
        .wr_en   (1'b1),
        .rd_en   (1'b1),
        .wr_addr (wr_addr),
        .rd_addr (rd_addr),
        .din     (mic_signal),
        .dout    (delayed_signal)
    );
endmodule
```
- This is the top level module that connects the counter and the dual port RAM 
- Note that the `parameter ADDRESS_WIDTH = 9` to allow for 512 locations of 8 bit samples
- `mic_signal` is the 8 bit audio sample from the Vbuddy

# sigdelay_tb.cpp
```cpp
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Vsigdelay.h"
#include "vbuddy.cpp"     // include vbuddy code
#define MAX_SIM_CYC 1000000
#define ADDRESS_WIDTH 9
#define RAM_SZ pow(2,ADDRESS_WIDTH)

int main(int argc, char **argv, char **env) {
  int simcyc;     // simulation clock count
  int tick;       // each clk cycle has two ticks for two edges
  
  Verilated::commandArgs(argc, argv);
  // init top verilog instance
  Vsigdelay* top = new Vsigdelay;
  // init trace dump
  Verilated::traceEverOn(true);
  VerilatedVcdC* tfp = new VerilatedVcdC;
  top->trace (tfp, 99);
  tfp->open ("sigdelay.vcd");
  
  // init Vbuddy
  if (vbdOpen()!=1) return(-1);
  vbdHeader("L2T3:Delay");
  //vbdSetMode(1);        // Flag mode set to one-shot

  // initialize simulation input
  top->clk = 1;
  top->rst = 0;
  top->wr = 1;
  top->rd = 1;
  top->offset = 64;

  // intialize variables for analogue output
  vbdInitMicIn(RAM_SZ);

  // run simulation for MAX_SIM_CYC clock cycles
  for (simcyc=0; simcyc<MAX_SIM_CYC; simcyc++) {
    // dump variables into VCD file and toggle clock
    for (tick=0; tick<2; tick++) {
      tfp->dump (2*simcyc+tick);
      top->clk = !top->clk;
      top->eval ();
    }

    top->mic_signal = vbdMicValue();
    top->offset = abs(vbdValue());     // adjust delay by changing incr

    // plot RAM input/output, send sample to DAC buffer, and print cycle count
    vbdPlot(int (top->mic_signal), 0, 255);
    vbdPlot(int (top->delayed_signal), 0, 255);
    vbdCycle(simcyc);
    
    // either simulation finished, or 'q' is pressed
    if ((Verilated::gotFinish()) || (vbdGetkey()=='q'))
      exit(0);
  }

  vbdClose();     // ++++
  tfp->close();
  printf("Exiting\n");
  exit(0);
}
```
