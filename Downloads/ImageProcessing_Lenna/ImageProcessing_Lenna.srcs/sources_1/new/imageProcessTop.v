`timescale 1ns / 1ps

module imageProcessTop(
input   axi_clk,
input   axi_reset_n,

// slave interface
input   i_data_valid,
input [7:0] i_data,
output  o_data_ready,

// master interface
output  o_data_valid,
output [7:0] o_data,
input   i_data_ready,

// interrupt
output  o_intr
);

wire [71:0] pixel_data;
wire pixel_data_valid;
wire axis_prog_full;
wire [7:0] convolved_data;
wire convolved_data_valid;

assign o_data_ready = !axis_prog_full;

imageControl IC(
.i_clk(axi_clk),
.i_rst(!axi_reset_n),
.i_pixel_data(i_data),
.i_pixel_data_valid(i_data_valid),
.o_pixel_data(pixel_data),
.o_pixel_data_valid(pixel_data_valid),
.o_intr(o_intr)
);

conv conv(
.i_clk(axi_clk),
.i_pixel_data(pixel_data),
.i_pixel_data_valid(pixel_data_valid),
.o_convolved_data(convolved_data),
.o_convolved_data_valid(convolved_data_valid)
);

outputBuffer OB(
.wr_rst_busy(),
.rd_rst_busy(),
.s_aclk(axi_clk),
.s_aresetn(axi_reset_n),
.s_axis_tvalid(convolved_data_valid),
.s_axis_tready(),
.s_axis_tdata(convolved_data),
.m_axis_tvalid(o_data_valid),
.m_axis_tready(i_data_ready),
.m_axis_tdata(o_data),
.axis_prog_full(axis_prog_full)
);

endmodule