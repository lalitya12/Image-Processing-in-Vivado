`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 31.03.2026 19:57:00
// Design Name: 
// Module Name: system_top
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
`default_nettype none

module system_top(

    // CLOCKS
    input  wire clk100,       // FPGA clock (for cam_init)
    input  wire clk25m,       // VGA/processing clock
    input  wire reset_n,

    // CAMERA INPUTS
    input  wire pclk,
    input  wire vsync,
    input  wire href,
    input  wire [7:0] cam_data,

    // SCCB (camera config)
    output wire sioc,
    inout  wire siod,

    // DEBUG OUTPUT (processed pixel)
    output wire [7:0] processed_pixel,
    output wire       processed_valid
);

    // =====================================================
    // 1. CAMERA INITIALIZATION
    // =====================================================

    wire cam_init_done;

    cam_init cam_init_inst (
        .i_clk(clk100),
        .i_rstn(reset_n),
        .i_cam_init_start(1'b1),   // auto start

        .o_siod(siod),
        .o_sioc(sioc),
        .o_cam_init_done(cam_init_done),

        .o_data_sent_done(),
        .o_SCCB_dout()
    );

    // =====================================================
    // 2. CAMERA CAPTURE
    // =====================================================

    wire [18:0] cam_addr;
    wire [11:0] cam_pixel;
    wire        cam_wr;

    cam_capture cam_cap_inst (
        .i_pclk(pclk),
        .i_vsync(vsync),
        .i_href(href),
        .i_D(cam_data),
        .i_cam_done(cam_init_done),

        .o_pix_addr(cam_addr),
        .o_pix_data(cam_pixel),
        .o_wr(cam_wr)
    );

    // =====================================================
    // 3. BRAM (FRAME BUFFER)
    // =====================================================

    wire [11:0] bram_data;

    // simple read address generator
    reg [18:0] rd_addr;

    always @(posedge clk25m) begin
        if (!reset_n)
            rd_addr <= 0;
        else
            rd_addr <= rd_addr + 1;
    end

    mem_bram bram_inst (
        // WRITE SIDE (camera domain)
        .i_wclk(pclk),
        .i_wr(cam_wr),
        .i_wr_addr(cam_addr),

        // READ SIDE (processing domain)
        .i_rclk(clk25m),
        .i_rd(1'b1),
        .i_rd_addr(rd_addr),

        .i_bram_en(1'b1),
        .i_bram_data(cam_pixel),

        .o_bram_data(bram_data)
    );

    // =====================================================
    // 4. RGB444 → GRAYSCALE
    // =====================================================

    wire [3:0] R = bram_data[11:8];
    wire [3:0] G = bram_data[7:4];
    wire [3:0] B = bram_data[3:0];

    wire [7:0] gray;

    assign gray = (R + (G << 1) + B) >> 2;

    // =====================================================
    // 5. STREAM GENERATION
    // =====================================================

    // Always valid stream (continuous scan)
    wire stream_valid = 1'b1;

    // =====================================================
    // 6. IMAGE PROCESSING CORE
    // =====================================================

    wire [7:0] proc_data;
    wire       proc_valid;

    imageProcessTop proc_inst (
        .axi_clk(clk25m),
        .axi_reset_n(reset_n),

        .i_data_valid(stream_valid),
        .i_data(gray),
        .o_data_ready(),

        .o_data_valid(proc_valid),
        .o_data(proc_data),
        .i_data_ready(1'b1),

        .o_intr()
    );

    // =====================================================
    // 7. OUTPUT
    // =====================================================

    assign processed_pixel  = proc_data;
    assign processed_valid  = proc_valid;

endmodule
