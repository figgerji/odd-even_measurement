`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create data: 2022/03/08 10:14:20
// Design Name:
// Module Name: Cycle_measurement
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
//? V2奇偶周期计数方案，奇偶每次应答可能错位，取idle后进入的第一个周期为奇数周期
//? 取使能后的第一个上升沿开始计数，在经历指定cycle后的第一个上升沿后的第3个clk上报计数，3个clk使用计数结果进行运算
// 湿哒哒sd??

module Cycle_measurement(input sys_rstn,                                        // *复位
                         input sys_clk,                                         // *系统时钟100MHz
                         input singal,                                          // *测频信号5-10kHZ
                         input en_sig,                                          // *模块使能
                         input [2:0] right_shift,                               // *结果的右移位数，如right_shift = 4，奇偶各平均16次，1~5
                         output [23:0] average_odd,                             // *平均后的奇数周期计数
                         output [23:0] average_even,                            // *平均后的偶数周期计数
                         output reg cycle_over,                                 // *数据就绪
                         output reg error);                                     // *输出周期内出现问题
    reg odd_cnt_over;                                                           // *单奇数周期计数结果就绪
    reg even_cnt_over;                                                          // *单偶数周期计数结果就绪
    reg [15:0] odd_cnt;                                                         // *奇数周期计数器
    reg [15:0] even_cnt;                                                        // *偶数周期计数器
    reg [15:0] odd_cnt_reg;                                                     // *单奇数周期计数结果
    reg [15:0] even_cnt_reg;                                                    // *单偶数周期计数结果
    wire [7:0] cycle_N;                                                         // *上升沿计数目标
    reg [7:0] cycle_cnt;                                                        // *上升沿的周期计数
    reg [7:0] cycle_cnt_1clk;                                                   // *cycle_cnt打1拍
    reg [7:0] cycle_cnt_2clk;                                                   // *cycle_cnt打2拍
    localparam cnt_over_normal = 16'd2_000;                                     // *连续的奇偶周期最少计数若为100M计数5~10k的奇偶，应为20_000~40_000
    reg [1:0] positive_edge;                                                    //*上升沿检测寄存器
    wire singal_pos;                                                            //*上升沿结果
    reg state_sign;                                                             //*奇偶状态，1奇0偶
    localparam idle = 2'd0,odd_wait = 2'd1,odd_state = 2'd2,even_state = 2'd3;
    reg [1:0] state,next_state;
    always @(*) begin
        case (state)
            idle:next_state       = en_sig?odd_wait:idle;
            odd_wait:next_state   = state_sign?odd_state:odd_wait;
            odd_state:next_state  = state_sign?odd_state:even_state;
            even_state:next_state = state_sign?odd_state:even_state;
            default:next_state    = idle;
        endcase
    end
    
    // ?状态转移，复位或取消使能进入闲置状态
    always @(posedge sys_clk or negedge sys_rstn) begin
        if (!sys_rstn)
            state <= idle;
        else if (!en_sig)
            state <= idle;
        else if (cycle_over)
            state <= idle;
        else
            state <= next_state;
    end
    
    // ?上升沿判断，上升沿后第2个时钟待用(1.1~2.1)
    always @(posedge sys_clk or negedge sys_rstn) begin
        if (!sys_rstn)
            positive_edge <= 2'd0;
        else if (!en_sig)
            positive_edge <= 2'd0;
        else
            positive_edge <= {positive_edge[0],singal};
    end
    assign singal_pos = ~positive_edge[1]&positive_edge[0];
    
    // ?state_sign通过singal_pos作为奇偶周期分界线，上升沿后第3个时钟待用(2.1~n+2.1)
    // ?复位和idle状态置0，奇数为1，偶数为0。
    always @(posedge sys_clk or negedge sys_rstn) begin
        if (!sys_rstn)
            state_sign <= 1'd0;
        else if (!en_sig)
            state_sign <= 1'd0;
        else if (singal_pos)
            state_sign <= ~state_sign;
        else
            state_sign <= state_sign;
    end
    
    // ?奇偶周期odd_cnt和even_cnt计数，上升沿后第2个时钟待用(1.1~n+1.1)
    always @(posedge sys_clk or negedge sys_rstn) begin
        if (!sys_rstn) begin
            odd_cnt_over  <= 1'd0;
            even_cnt_over <= 1'd0;
            odd_cnt       <= 16'd0;
            even_cnt      <= 16'd0;
            odd_cnt_reg   <= 16'd0;
            even_cnt_reg  <= 16'd0;
        end
        else if (!en_sig) begin
            odd_cnt_over  <= 1'd0;
            even_cnt_over <= 1'd0;
            odd_cnt       <= 16'd0;
            even_cnt      <= 16'd0;
            odd_cnt_reg   <= 16'd0;
            even_cnt_reg  <= 16'd0;
        end
        else begin
            case (state)
                odd_state: begin
                    if (singal_pos == 1'b0) begin               //*从3.1~n+3.1为odd，从3~n+1为singal_pos = 1'b0
                        odd_cnt_over  <= 1'd0;
                        odd_cnt       <= odd_cnt+1'd1;
                        odd_cnt_reg   <= odd_cnt_reg;
                        even_cnt_over <= 1'd0;
                        even_cnt      <= 16'd0;
                        even_cnt_reg  <= even_cnt_reg;
                    end
                    else begin
                        odd_cnt_over  <= 1'd1;
                        odd_cnt       <= 16'd0;
                        odd_cnt_reg   <= odd_cnt+16'd2;           //*因为每个状态的第一个会被漏掉，最后一个计数需要加上
                        even_cnt_over <= 1'd0;
                        even_cnt      <= 16'd0;
                        even_cnt_reg  <= even_cnt_reg;
                    end
                end
                even_state: begin
                    if (singal_pos == 1'b0) begin
                        even_cnt_over <= 1'd0;
                        even_cnt      <= even_cnt+1'd1;
                        even_cnt_reg  <= even_cnt_reg;
                        odd_cnt_over  <= 1'd0;
                        odd_cnt       <= 16'd0;
                        odd_cnt_reg   <= odd_cnt_reg;
                    end
                    else begin
                        even_cnt_over <= 1'd1;
                        even_cnt      <= 16'd0;
                        even_cnt_reg  <= even_cnt+16'd2;
                        odd_cnt_over  <= 1'd0;
                        odd_cnt       <= 16'd0;
                        odd_cnt_reg   <= odd_cnt_reg;
                    end
                end
                default: begin
                    odd_cnt_over  <= 1'd0;
                    even_cnt_over <= 1'd0;
                    odd_cnt       <= 16'd0;
                    even_cnt      <= 16'd0;
                    odd_cnt_reg   <= 16'd0;
                    even_cnt_reg  <= 16'd0;
                end
            endcase
        end
    end
    
    assign cycle_N = (8'd2<<right_shift)+1'd1;
    // ?singal_pos = 1,周期+1，上升沿后第3个时钟待用(2.1~n+2.1)
    always @(posedge sys_clk or negedge sys_rstn) begin
        if (!sys_rstn)
            cycle_cnt <= 8'd0;
        else if (!en_sig)
            cycle_cnt <= 8'd0;
        else if (cycle_cnt < cycle_N) begin                                //*cycle_N = 33时是完整16个奇偶周期
            if (singal_pos == 1'b1)
                cycle_cnt <= cycle_cnt+1'd1;
            else
                cycle_cnt <= cycle_cnt;
        end
        else
            cycle_cnt <= cycle_cnt;
    end
    always @(posedge sys_clk) begin
        cycle_cnt_1clk <= cycle_cnt;                           //*延后1个时钟周期
        cycle_cnt_2clk <= cycle_cnt_1clk;                      //*延后2个时钟周期
    end
    
    // ?cycle_cnt> = cycle_N，cycle_over = 1，打两拍，上升沿后第5个时钟待用(5.1)
    always @(posedge sys_clk or negedge sys_rstn) begin
        if (!sys_rstn)
            cycle_over <= 1'd0;
        else if (!en_sig)
            cycle_over <= 1'd0;
        else if (cycle_cnt_2clk >= cycle_N)
            cycle_over <= 1'd1;
        else
            cycle_over <= 1'd0;
    end
    
    // ?检查odd_cnt_over+even_cnt_over，异常时，error = 1
    // ?打两拍，上升沿后第5个时钟待用(5.1)
    always @(posedge sys_clk or negedge sys_rstn) begin
        if (!sys_rstn)
            error <= 1'd0;
        else if (!en_sig)
            error <= 1'd0;
        else if ((odd_cnt_over||even_cnt_over)&&(cycle_cnt_2clk>2)) begin
            if (odd_cnt_reg+even_cnt_reg < cnt_over_normal)
                error <= 1'd1;
            else
                error <= 1'd0;
        end
        else
            error <= 1'd0;
    end
    
    // ?计算总数值并平均
    reg [23:0] sum_odd;
    reg [23:0] sum_even;
    always @(posedge sys_clk or negedge sys_rstn) begin
        if (!sys_rstn)
            sum_odd <= 24'd0;
        else if (!en_sig)
            sum_odd <= 24'd0;
        else if (odd_cnt_over)
            sum_odd <= sum_odd+odd_cnt_reg;
        else
            sum_odd <= sum_odd;
    end
    always @(posedge sys_clk or negedge sys_rstn) begin
        if (!sys_rstn)
            sum_even <= 24'd0;
        else if (!en_sig)
            sum_even <= 24'd0;
        else if (even_cnt_over)
            sum_even <= sum_even+even_cnt_reg;
        else
            sum_even <= sum_even;
    end
    assign average_odd  = sum_odd>>right_shift;
    assign average_even = sum_even>>right_shift;
endmodule
