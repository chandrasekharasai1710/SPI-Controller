module spi_master #(
    parameter CLK_DIV = 4
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire        start,
    input  wire [7:0]  tx_data,
    output reg  [7:0]  rx_data,
    output reg         done,
    output reg         sclk,
    output reg         mosi,
    input  wire         miso,
    output reg          cs_n
);

    localparam IDLE = 2'd0, LOAD = 2'd1, SHIFT = 2'd2, DONE = 2'd3;

    reg [1:0]  state;
    reg [2:0]  bit_cnt;
    reg [7:0]  shift_tx;
    reg [7:0]  shift_rx;
    reg [$clog2(CLK_DIV):0] div_cnt;
    reg        sclk_en;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt <= 0;
            sclk    <= 1'b0;
        end else if (sclk_en) begin
            if (div_cnt == CLK_DIV-1) begin
                div_cnt <= 0;
                sclk    <= ~sclk;
            end else begin
                div_cnt <= div_cnt + 1;
            end
        end else begin
            div_cnt <= 0;
            sclk    <= 1'b0;
        end
    end

    wire sclk_rise = sclk_en && (div_cnt == CLK_DIV-1) && (sclk == 1'b0);
    wire sclk_fall = sclk_en && (div_cnt == CLK_DIV-1) && (sclk == 1'b1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            cs_n     <= 1'b1;
            mosi     <= 1'b0;
            done     <= 1'b0;
            sclk_en  <= 1'b0;
            bit_cnt  <= 3'd0;
            rx_data  <= 8'd0;
            shift_tx <= 8'd0;
            shift_rx <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        shift_tx <= tx_data;
                        bit_cnt  <= 3'd7;
                        cs_n     <= 1'b0;
                        sclk_en  <= 1'b1;
                        state    <= LOAD;
                    end
                end

                LOAD: begin
                    mosi  <= shift_tx[7];
                    state <= SHIFT;
                end

                SHIFT: begin
                    if (sclk_fall) begin
                        shift_rx <= {shift_rx[6:0], miso};
                        if (bit_cnt == 0) begin
                            state <= DONE;
                        end else begin
                            bit_cnt  <= bit_cnt - 1;
                            shift_tx <= {shift_tx[6:0], 1'b0};
                            mosi     <= shift_tx[6];
                        end
                    end
                end

                DONE: begin
                    sclk_en <= 1'b0;
                    cs_n    <= 1'b1;
                    rx_data <= shift_rx;
                    done    <= 1'b1;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
