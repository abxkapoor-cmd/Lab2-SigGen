- Goal: Build a signal generator by combining a counter with a ROM, and displaying the results on the Vbuddy. 
# `rom.sv`
```systemverilog
module rom #(
    parameter ADDRESS_WIDTH = 8,
    parameter DATA_WIDTH    = 8
)(
    input  logic                     clk,
    input  logic [ADDRESS_WIDTH-1:0] addr,
    output logic [DATA_WIDTH-1:0]    dout
);
    logic [DATA_WIDTH-1:0] rom_array [2**ADDRESS_WIDTH-1:0];
    initial begin
        $display("Loading rom.");
        $readmemh("sinerom.mem", rom_array);
    end
    always_ff @(posedge clk)
        // output is synchronous
        dout <= rom_array[addr];
endmodule
```

- This rom module is a lookup table that holds the 256 sine values and returns the one at the address that you provide. The array is 256 entries each holding 8 bits. The initial block runs once at the start of the simulation and the contents of `sinerom.mem` are loaded into the array. 

- On every rising clock edge the address of the memory location that was read in the previous cycle is loaded into the output. This is because this read is synchronous. 

- `Dout` (the output) is what goes to the Vbuddy Plot. The counter produces `addr`, which sweeps through the table.  
# `Sinegen.py`
```python
import math
import string

f = open("sinerom.mem","w")

for i in range(256):
    v = int(math.cos(2*3.1416*i/256)*127+127)
    if (i+1)%16 == 0:
        s = "{hex:2X}\n"
    else:
        s = "{hex:2X} "
    f.write(s.format(hex=v))
f.close()
```

- `sinegen.py` writes a 256-entry lookup table for one full wave cycle to `sinerom.mem`, ready to be loaded into a ROM with `$readmemh`.
- A loop runs `i` from 0 to 255, and each iteration turns `i` into an angle (`2π·i/256`) so the 256 entries cover exactly one turn. It takes the cosine of that angle and scales it with `*127 + 127`, so values that would be -1 to 1 land in an unsigned 8-bit range of 0 to 254.
- Each value is written as two-digit uppercase hex, with a newline after every 16th entry so the file is 16 lines of 16 values.
- The file is closed at the end.
## `Sinerom.mem`
```
FE FD FD FD FD FD FC FC FB FA FA F9 F8 F7 F6 F5
F4 F3 F1 F0 EF ED EB EA E8 E6 E5 E3 E1 DF DD DA
D8 D6 D4 D1 CF CD CA C8 C5 C2 C0 BD BA B8 B5 B2
AF AC A9 A6 A3 A0 9D 9A 97 94 91 8E 8B 88 85 82
7E 7B 78 75 72 6F 6C 69 66 63 60 5D 5A 57 54 51
4E 4B 48 45 43 40 3D 3B 38 35 33 30 2E 2C 29 27
25 23 20 1E 1C 1A 18 17 15 13 12 10  E  D  C  A
 9  8  7  6  5  4  3  3  2  1  1  0  0  0  0  0
 0  0  0  0  0  0  1  1  2  3  3  4  5  6  7  8
 9  A  C  D  E 10 12 13 15 17 18 1A 1C 1E 20 23
25 27 29 2C 2E 30 33 35 38 3B 3D 40 43 45 48 4B
4E 51 54 57 5A 5D 60 63 66 69 6C 6F 72 75 78 7B
7F 82 85 88 8B 8E 91 94 97 9A 9D A0 A3 A6 A9 AC
AF B2 B5 B8 BA BD C0 C2 C5 C8 CA CD CF D1 D4 D6
D8 DA DD DF E1 E3 E5 E6 E8 EA EB ED EF F0 F1 F3
F4 F5 F6 F7 F8 F9 FA FA FB FC FC FD FD FD FD FD
```


# `Sinegen_tb.cpp`
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
  vbdHeader("L2T1: SigGen");
  //vbdSetMode(1);        // Flag mode set to one-shot
  // initialize simulation inputs
  top->clk = 1;
  top->rst = 0;
  top->en = 1;
  top->incr = 1;
  
  // run simulation for MAX_SIM_CYC clock cycles
  for (simcyc=0; simcyc<MAX_SIM_CYC; simcyc++) {
    // dump variables into VCD file and toggle clock
    for (tick=0; tick<2; tick++) {
      tfp->dump (2*simcyc+tick);
      top->clk = !top->clk;
      top->eval ();
    }
    top->incr = vbdValue();
    // plot ROM output and print cycle count
    vbdPlot(int (top->dout), 0, 255);
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
- This testbench creates the `Vsinegen` module (the Verilated `Sinegen` module), turns on tracing and opens `sinegen.vcd` for GTKWave. `vbdOpen()` connects to the Vbuddy and returns early if it can't, and `vbdHeader()` puts a title on the display. 
- Initial inputs: `clk = 1, rst = 0, en = 1, incr = 1` . The last input `incr = 1` means that we have one ROM entry per clock cycle. 
- Main loop: each `simcyc` is one clock cycle, made of two ticks (the inner tick loop toggles clk and calls `eval()` for each edge).
- Knob input: `top->incr = vbdValue()` reads the rotary encoder every cycle. A bigger value steps through the TOM faster, so it raises the frequency of the wave. 
- Output: `vbdPlot(int(top->dout), 0, 255)` draws the ROM output as a dot on the Vbuddy screen, and `vbdCycle(simcyc)` shows the cycle count.
- Stopping: The loop ends after `MAX_SIM_CYC ` is reached or when the simulation finishes or when you press `q`.
