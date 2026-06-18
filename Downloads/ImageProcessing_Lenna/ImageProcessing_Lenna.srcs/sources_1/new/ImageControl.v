`timescale 1ns / 1ps

module imageControl #(
    parameter IMG_WIDTH  = 512,
    parameter IMG_HEIGHT = 512
)(
    input              i_clk,
    input              i_rst,
    input  [7:0]       i_pixel_data,
    input              i_pixel_data_valid,

    output reg [71:0]  o_pixel_data,
    output             o_pixel_data_valid,
    output reg         o_intr
);

    // --------------------------------------------------
    // INTERNAL REGISTERS
    // --------------------------------------------------
    reg [8:0] col_cnt;          // 0..511
    reg [8:0] row_cnt;          // 0..511

    reg [1:0] wr_line_sel;      // which line buffer to write
    reg [1:0] rd_line_sel;      // which line buffers to read

    reg        rd_enable;

    // line buffer I/O
    reg  [3:0] lb_wr_valid;
    reg  [3:0] lb_rd_en;

    wire [23:0] lb0data, lb1data, lb2data, lb3data;

    // --------------------------------------------------
    // OUTPUT VALID
    // --------------------------------------------------
    assign o_pixel_data_valid = rd_enable;

    // --------------------------------------------------
    // COLUMN / ROW COUNTERS
    // --------------------------------------------------
    always @(posedge i_clk) begin
        if (i_rst) begin
            col_cnt <= 0;
            row_cnt <= 0;
        end
        else if (i_pixel_data_valid) begin
            if (col_cnt == IMG_WIDTH-1) begin
                col_cnt <= 0;
                if (row_cnt < IMG_HEIGHT)
                    row_cnt <= row_cnt + 1;
            end else begin
                col_cnt <= col_cnt + 1;
            end
        end
    end

    // --------------------------------------------------
    // WRITE LINE BUFFER ROTATION
    // --------------------------------------------------
    always @(posedge i_clk) begin
        if (i_rst)
            wr_line_sel <= 0;
        else if (i_pixel_data_valid && col_cnt == IMG_WIDTH-1)
            wr_line_sel <= wr_line_sel + 1;
    end

    // --------------------------------------------------
    // READ ENABLE (start after 3 rows)
    // --------------------------------------------------
    always @(posedge i_clk) begin
        if (i_rst)
            rd_enable <= 1'b0;
        else if (row_cnt >= 3)
            rd_enable <= 1'b1;
    end

    // --------------------------------------------------
    // INTERRUPT: ONE PER LINE
    // --------------------------------------------------
    always @(posedge i_clk) begin
        if (i_rst)
            o_intr <= 1'b0;
        else if (rd_enable && col_cnt == IMG_WIDTH-1)
            o_intr <= 1'b1;
        else
            o_intr <= 1'b0;
    end

    // --------------------------------------------------
    // READ LINE BUFFER ROTATION
    // --------------------------------------------------
    always @(posedge i_clk) begin
        if (i_rst)
            rd_line_sel <= 0;
        else if (rd_enable && col_cnt == IMG_WIDTH-1)
            rd_line_sel <= rd_line_sel + 1;
    end

    // --------------------------------------------------
    // LINE BUFFER WRITE ENABLE
    // --------------------------------------------------
    always @(*) begin
        lb_wr_valid = 4'b0000;
        lb_wr_valid[wr_line_sel] = i_pixel_data_valid;
    end

    // --------------------------------------------------
    // LINE BUFFER READ ENABLE
    // --------------------------------------------------
    always @(*) begin
        lb_rd_en = 4'b0000;
        if (rd_enable) begin
            case (rd_line_sel)
                0: lb_rd_en = 4'b0111;
                1: lb_rd_en = 4'b1110;
                2: lb_rd_en = 4'b1101;
                3: lb_rd_en = 4'b1011;
            endcase
        end
    end

    // --------------------------------------------------
    // 3×3 WINDOW ASSEMBLY
    // --------------------------------------------------
    always @(*) begin
        case (rd_line_sel)
            0: o_pixel_data = {lb2data, lb1data, lb0data};
            1: o_pixel_data = {lb3data, lb2data, lb1data};
            2: o_pixel_data = {lb0data, lb3data, lb2data};
            3: o_pixel_data = {lb1data, lb0data, lb3data};
        endcase
    end

    // --------------------------------------------------
    // LINE BUFFERS
    // --------------------------------------------------
    lineBuffer lb0 (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_data(i_pixel_data),
        .i_data_valid(lb_wr_valid[0]),
        .o_data(lb0data),
        .i_rd_data(lb_rd_en[0])
    );

    lineBuffer lb1 (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_data(i_pixel_data),
        .i_data_valid(lb_wr_valid[1]),
        .o_data(lb1data),
        .i_rd_data(lb_rd_en[1])
    );

    lineBuffer lb2 (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_data(i_pixel_data),
        .i_data_valid(lb_wr_valid[2]),
        .o_data(lb2data),
        .i_rd_data(lb_rd_en[2])
    );

    lineBuffer lb3 (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_data(i_pixel_data),
        .i_data_valid(lb_wr_valid[3]),
        .o_data(lb3data),
        .i_rd_data(lb_rd_en[3])
    );

endmodule