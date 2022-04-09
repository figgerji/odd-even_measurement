`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2022/03/21 20:04:18
// Design Name:
// Module Name: tb_Cycle_measurement
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module tb_Cycle_measurement ();
    // Cycle_measurement Inputs
    reg   sys_rstn;
    reg   sys_clk;
    reg   singal;
    reg   en_sig;
    reg   [2:0]  right_shift;
    // Cycle_measurement Outputs
    wire  [23:0]  average_odd;
    wire  [23:0]  average_even;
    wire  cycle_over;
    wire  error;
    initial begin
        sys_clk     = 0;
        sys_rstn    = 0;
        en_sig      = 0;
        singal      = 1'b0;
        right_shift = 3'd4;
        forever begin
            #30000 singal = 1'b0;           //*10k
            #30000 singal = 1'b1;           //*10k
            #20000 singal = 1'b0;           //*10k
            #20000 singal = 1'b1;           //*10k
        end
        #1000;
        sys_rstn     = 1;
        #2000 en_sig = 1;
        
        #5_000_000 en_sig = 0;
    end
    always #5 sys_clk = ~sys_clk;
    Cycle_measurement  u_Cycle_measurement (
    .sys_rstn                (sys_rstn),
    .sys_clk                 (sys_clk),
    .singal                  (singal),
    .en_sig                  (en_sig),
    .right_shift             (right_shift   [2:0]),
    .average_odd             (average_odd   [23:0]),
    .average_even            (average_even  [23:0]),
    .cycle_over              (cycle_over),
    .error                   (error)
    );
endmodule
