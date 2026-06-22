/*Note:  Calculations
       Total Period = HIGH_TIME + LOW_TIME
                    = 125 * 10ns + 125 * 10ns
                    = 2500ns
       Frequency    = 400 KHz
 */

//@ CLK=100MHz SCL=400KHz
module NRG1_EEPROM_I2C_top #(parameter 
	     HIGH_TIME=10'd125,
	     LOW_TIME =10'd125,DATA_WIDTH = 8'd8,DEVICE_ID_WIDTH = 7)
( output SCL,
  inout SDA,
  input CLK,
  output [DATA_WIDTH-1:0]receive_read_reg,
  input RST, 
  input RW,
  input [DATA_WIDTH-1:0]address,
  input [DATA_WIDTH-1:0]datain,
  input [DEVICE_ID_WIDTH-1:0]device_id
);
localparam IDLE = 5'b00000;
localparam START = 5'b00001;
localparam TX_DEVICE_ID = 5'b00010;
localparam ACK_NACK_1 = 5'b00011;
localparam MEM_ADDRESS = 5'b00100;
localparam ACK_NACK_2 =5'b00101;
localparam DATA_SEND = 5'b00110;
localparam ACK_NACK_3 = 5'b00111;
localparam STOP = 5'b01000;
localparam READ_MODE_CONFIG = 5'b00110;
localparam REPEATED_START = 5'b00111;
localparam SEND_READ_MODE_CONFIG = 5'b01000;
localparam ACK_NACK_4 = 5'b01001;
localparam READ_DATA = 5'b01010;
localparam STOP_READ = 5'b01011;
///////////////internal registers/////////////////////
reg ack;
reg [DATA_WIDTH-1:0]device_reg;
reg [9:0]h_count;
reg [9:0]l_count;
reg sda_oen;
reg scl_oen;
reg scl_o;
reg sda_o;
reg [4:0]nstate;
reg scl_hi_by2;
reg scl_lo_by2;
reg sda_hi_by2;
reg scl_low;
reg scl_high;
reg [3:0]cycle;
reg [DATA_WIDTH-1:0]receive_data_reg;
reg [4:0]delay_counter;
reg scl_hi_time_start;
reg scl_low_sync;
reg [DATA_WIDTH-1:0]address_lat;
reg [DATA_WIDTH-1:0]datain_lat;
reg  [DEVICE_ID_WIDTH-1:0]device_id_lat;

wire sda_i;
wire scl_low_neg_edge;
wire sdaout;
wire sclout;


////////////////////////////////////////////////////////////

///////////////////SCL clock generation////////////////////
always @(posedge CLK or negedge RST) begin 
	if (!RST) begin 
	   scl_low_sync<=0; 
	end
	else begin 
           scl_low_sync<=scl_low;
	end 
end 
assign scl_low_neg_edge= ~scl_low & scl_low_sync;

always @(posedge CLK or negedge RST) begin 
	if (!RST) begin 
 		h_count<=0;
		l_count<=0;	
	end

	else if (scl_oen==1 && scl_low==1'b0) begin
               	h_count<=h_count+1'b1;
               	l_count<=0;
       end
       else if (scl_oen==1'b1 && scl_high==1'b0) begin
               	l_count<=l_count+1'b1;
               	h_count<=0;
       end
       else begin 
	       	h_count<=0;
           	l_count<=0;
       end 	       
end 

always @(posedge CLK or negedge RST)begin 

	if (!RST) begin 
		scl_high<=1'b1;
		scl_low<=1'b0;
		scl_hi_by2<=0;
	    	scl_lo_by2<=0;
	end 
	else if (h_count==HIGH_TIME-1) begin 
		     scl_high<=1'b0;
		     scl_low<=1'b1;
	     end 
	else if (l_count==LOW_TIME-1)begin
		     scl_high<=1;
		     scl_low<=0;
        end
	else if (h_count==HIGH_TIME/2 && scl_high)begin 
		     scl_hi_by2<=1'b1;
		     sda_hi_by2<=1'b1;
        end 
	else if(l_count==LOW_TIME/2 && scl_low)begin
		     scl_lo_by2<=1'b1;
	end 
	else begin
		     sda_hi_by2<=1'b0;
	         scl_lo_by2<=1'b0;
		     scl_hi_by2<=1'b0;
	end
end 

/////////////////////////////////////////////



always @(posedge CLK or negedge RST) begin
	if (!RST) begin 
		address_lat<=0;
		datain_lat<=0;
		device_id_lat<=0;
	end 
	else begin 
		device_id_lat<=device_id;
		address_lat<=address;
		datain_lat<=datain;
	end 	
end

          
always @(posedge CLK or negedge RST)
begin
	if (!RST)begin
	    
           sda_oen<=1'b0;
	       scl_oen<=1'b0;
	       scl_o<=1'b1;
	       sda_o<=1'b1;
	       cycle<=4'b0;
	       nstate<=IDLE;
	       receive_data_reg<=8'h0;  
	       ack<=1'b1;
	end
	else begin
	     if(RW==1'b0)
	     begin
		case (nstate)                             /// logic for 8 bit frame generation 
		IDLE:begin
			
			sda_oen<=0;
			scl_oen<=0;
		       	device_reg<={device_id_lat,RW};
		    	nstate<=START;
	     		cycle<=4'b0000;
			sda_o<=1'b1;

			end 	 
        	START:begin                                    ///logic for I2C start condition generation
	                	scl_o<=1'b1;
		            	scl_oen<=1'b1;
		        	if(scl_hi_by2==1'b1)
		         	begin
			            	sda_o<=1'b1;
			        	sda_oen<=1'b1;
		          	end   
		       		else if (scl_lo_by2==1'b1)
		        	begin 
			             	sda_o<=1'b0;
		       	         	sda_oen<=1'b1;
		        	end 
		       		else if (scl_low_neg_edge==1'b1) 
		       		begin 
				    	scl_hi_time_start<=0;
				    	nstate<=TX_DEVICE_ID;
				    	scl_o<=1'b0;
	
			   	end 	
		          	else 
		          	begin
			         	nstate<=nstate; 		       
	               		end 
	          	end
   	 	TX_DEVICE_ID: begin                                       ///logic for transmission of 8 bit frame ,combination of 7 bit device ID and RW(Read/Write)bit. 
                		if(scl_low==1'b1 )
                     			scl_o<=1'b1;
        	    		else
		             		scl_o<=1'b0;
		        		if(sda_hi_by2==1'b1)
					begin   
                      				if(cycle==8)  
						begin
                       					nstate<=ACK_NACK_1;            
		                			cycle<=4'b0;
		                			sda_oen<=1'b0;
       	       					end
                   			else  
					begin    
                        			sda_o<=device_reg[(DATA_WIDTH-1)-cycle];
                        			cycle<=cycle+1;
                         			nstate<=TX_DEVICE_ID; 
					end 
                            	end
	            	end	
         	ACK_NACK_1: begin                                     ///logic for ack/nack detection for device ID
                      		if(scl_low==1'b1 )
                        		scl_o<=1'b1;
        	         	else
		                	scl_o<=1'b0;
		                
                 		if (sda_i==1'b1 && scl_lo_by2==1'b1)
				    	ack<=1'b1;
			     	else if (sda_i==1'b0 && scl_lo_by2==1'b1)
			     		ack<=1'b0;
				
                  		if(scl_low_neg_edge && ~ack)  //ack
                     		begin 
                         		nstate<=MEM_ADDRESS;
                         		sda_oen<=1'b1;
                         		ack<=1'b1;
                         		cycle<=4'b0;
                       		end
                    		else if(scl_low_neg_edge && ack)  //nack
                         	begin 
                          		nstate<=IDLE;
                          		sda_oen<=1'b1;
                          		ack<=1'b1;
                          		cycle<=4'b0;
                          	end 
                     	end 
          	 MEM_ADDRESS: begin                                 /// logic for transmission of 8 bit memory address 
                            	if(scl_low==1'b1 )
                                	scl_o<=1'b1;
        	               	else
		                        scl_o<=1'b0;
		             	if(sda_hi_by2==1'b1) 
				begin   
                                	 if(cycle==8)  
                                	 begin
                                        	nstate<=ACK_NACK_2;            
		                                cycle<=4'b0;
		                               	sda_oen<=1'b0;
       	                         	end
                          	else          
                          		begin    
                                		sda_o<=address_lat[(DATA_WIDTH-1)-cycle];
                                		cycle<=cycle+1;
                                		nstate<=MEM_ADDRESS; 
                                 	end 
                              end
	            end	 
	       ACK_NACK_2: begin                            ///logic for ack/nack detection for memory address
                      		if(scl_low==1'b1 )
                        		scl_o<=1'b1;
        	         	else
		                	scl_o<=1'b0;
	         		if (sda_i==1'b1 && scl_lo_by2==1'b1)
				    	ack<=1'b1;
			     	else if (sda_i==1'b0 && scl_lo_by2==1'b1)
			     		ack<=1'b0;
				
                  		if(scl_low_neg_edge && ~ack)  //ack
                     		begin 
                         		nstate<=DATA_SEND;
                         		sda_oen<=1'b1;
                         		ack<=1'b1;
                         		cycle<=4'b0;
                       		end
                    		else if(scl_low_neg_edge && ack) //nack
                         	begin 
                          		nstate<=IDLE;
                          		sda_oen<=1'b1;
                          		ack<=1'b1;
                          		cycle<=4'b0;
                          	end 
                     	end 
           	DATA_SEND: begin                               /// logic for transmission of 8 bit data
                           	if(scl_low==1'b1 )
                                	scl_o<=1'b1;
        	               	else
		                        scl_o<=1'b0;
		                             
		              	if(sda_hi_by2==1'b1) 
				begin   
                                 	if(cycle==8)  
                                 	begin
                                        	nstate<=ACK_NACK_3;            
		                                cycle<=4'b0;
		                               	sda_oen<=1'b0;
       	                         	end
                          		else          
                          		begin    
                                		sda_o<=datain_lat[(DATA_WIDTH-1)-cycle];
                                		cycle<=cycle+1;
                                		nstate<=DATA_SEND; 
                             		end 
                              	end
	            	end	  
	        ACK_NACK_3: begin                          ///logic for ack/nack detection for data
              
                     		 if(scl_low==1'b1 )
                        		scl_o<=1'b1;
        	         	else
		                	scl_o<=1'b0;

                		 if (sda_i==1'b1 && scl_lo_by2==1'b1)
				    	ack<=1'b1;
			     	else if (sda_i==1'b0 && scl_lo_by2==1'b1)
			     		ack<=1'b0;
				
                  		if(scl_low_neg_edge && ~ack)  //ack
                     		begin 
                         		nstate<=STOP;
                         		sda_oen<=1'b1;
                         		sda_o<=1'b0;
                         		ack<=1'b1;
                         		cycle<=4'b0;
                      		 end
                    		else if(scl_low_neg_edge && ack) //nack
                         	begin 
                          		nstate<=IDLE;
                          		sda_oen<=1'b1;
                          		ack<=1'b1;
                          		cycle<=4'b0;
                          	end 
                     	end       
	              

		               
	          STOP: begin                             //logic for stop condition generation 

                                 	scl_o<=1'b1;
		                    	scl_oen<=1'b1;
		       
		                 if (sda_hi_by2==1'b1) 
				 begin 
			           	sda_o<=1'b1;
		       	            	sda_oen<=1'b1;
		             	 end 
		        
		              	else if (scl_low_neg_edge==1'b1) 
				begin 
		                      if(delay_counter==5'd20) 
		                      begin
		                            	delay_counter<=5'b0;
			                	nstate<=IDLE;
			              end
			             else  
				     	begin
			                	 delay_counter<=delay_counter+1;
			                    	 nstate<=nstate;
			        	end

	                         end     
	                      end   
	        	default: nstate<=IDLE;      
                endcase	
             end
             
         else if(RW==1'b1)                                     ///logic for 8 bit frame generation
            begin
                		case (nstate)
		IDLE:	begin
			
					sda_oen<=0;
					scl_oen<=0;
			   		device_reg<={device_id_lat,1'b0};
		    			nstate<=START;
	        			cycle<=4'b0000;
					sda_o<=1'b1;
				end 	 
        	START:	begin                                         ///logic for I2C start condition 
	                		scl_o<=1'b1;
		            		scl_oen<=1'b1;
		        		if(scl_hi_by2==1'b1)
		         		begin
			            		sda_o<=1'b1;
			             		sda_oen<=1'b1;
		          		end   
		       			else if (scl_lo_by2==1'b1)
		        		begin 
			             		sda_o<=1'b0;
		       	         		sda_oen<=1'b1;
		        		end 
		      	 		else if (scl_low_neg_edge==1'b1) 
		       			begin 
				    		scl_hi_time_start<=0;
				    		nstate<=TX_DEVICE_ID;
				    		scl_o<=1'b0;
	
			   		end 	
		          		else 
		          		begin
			         		nstate<=nstate; 		       
	               			end 
	          		end
    		TX_DEVICE_ID: begin                                            ///logic for transmission of 8 bit frame ,combination of 7 bit device ID and RW(Read/Write)bit.
                		if(scl_low==1'b1 )
                     			scl_o<=1'b1;
        	    		else
		             		scl_o<=1'b0;
		             
		        	if(sda_hi_by2==1'b1)
				begin   
                      			if(cycle==8)  
					begin
                       				nstate<=ACK_NACK_1;            
		               	 		cycle<=4'b0;
		                		sda_oen<=1'b0;
       	       				end
                   			else  
					begin    
                        			sda_o<=device_reg[(DATA_WIDTH-1)-cycle];
                        			cycle<=cycle+1;
                         			nstate<=TX_DEVICE_ID; 
					end 
                            	end
	           	end	
         	ACK_NACK_1: begin                                   /// logic for ack/nack detection for device ID

                      		if(scl_low==1'b1 )
                        		scl_o<=1'b1;
        	         	else
		                	scl_o<=1'b0; 
                 		if (sda_i==1'b1 && scl_lo_by2==1'b1)
				    	ack<=1'b1;
			     	else if (sda_i==1'b0 && scl_lo_by2==1'b1)
			     		ack<=1'b0;				
                  		if(scl_low_neg_edge && ~ack)  //ack
                     		begin 
                         		nstate<=MEM_ADDRESS;
                         		sda_oen<=1'b1;
                         		ack<=1'b1;
                         		cycle<=4'b0;
                       		end
                    		else if(scl_low_neg_edge && ack) //nack
                         	begin 
                          		nstate<=IDLE;
                          		sda_oen<=1'b1;
                          		ack<=1'b1;
                          		cycle<=4'b0;
                          	end 
                     	end  
           MEM_ADDRESS: begin                                    /// logic for transmision of memory address to be red
                            	if(scl_low==1'b1 )
                                	scl_o<=1'b1;
        	               	else
		                        scl_o<=1'b0;
		                             
		            	if(sda_hi_by2==1'b1)
				begin   
                                 	if(cycle==8)  
                                 	begin
                                        	nstate<=ACK_NACK_2;            
		                                cycle<=4'b0;
		                               	sda_oen<=1'b0;
       	                         	end
                          		else          
                          		begin    
                                		sda_o<=address_lat[(DATA_WIDTH-1)-cycle];
                                		cycle<=cycle+1;
                                		nstate<=MEM_ADDRESS; 
                              		end 
                              end
	            end	 
	ACK_NACK_2: begin                                ///logic for ack/nack detection of memory address
                      		if(scl_low==1'b1 )
                        		scl_o<=1'b1;
        	     		else
		                	scl_o<=1'b0;
 
                		if (sda_i==1'b1 && scl_lo_by2==1'b1)
					ack<=1'b1;
				else if (sda_i==1'b0 && scl_lo_by2==1'b1)
			     		ack<=1'b0;
				
                  		if(scl_low_neg_edge && ~ack)  //ack
                     		begin 
                         		nstate<=READ_MODE_CONFIG;
                         		sda_oen<=1'b1;
                         		ack<=1'b1;
                         		cycle<=4'b0;
                      	 	end
                    		else if(scl_low_neg_edge && ack) //nack
                       		begin 
                          		nstate<=IDLE;
                          		sda_oen<=1'b1;
                          		ack<=1'b1;
                          		cycle<=4'b0;
                     		end 
                end 
         
         READ_MODE_CONFIG: begin                                                                     ///logic for 8 bit frame generation
			 device_reg<={device_id_lat,1'b1};
			cycle<=4'b0000;
			sda_o<=1'b1; 
		     	nstate<=REPEATED_START;
                    end
                                                                                          
         REPEATED_START:begin                                                                ///logic for I2C repeated start condition
                                scl_o<=1'b1;
		              	scl_oen<=1'b1;
		              	if(scl_hi_by2==1'b1)
		            	begin
			          	sda_o<=1'b1;
			              	sda_oen<=1'b1;
		              	end   
		              	else if (scl_lo_by2==1'b1)
		              	begin 
			               	sda_o<=1'b0;
		       	             	sda_oen<=1'b1;
		            	 end 
		              	else if (scl_low_neg_edge==1'b1) 
		              	begin 
				     	scl_hi_time_start<=0;
				  	nstate<=SEND_READ_MODE_CONFIG;
				    	scl_o<=1'b0;
	
               			end 	
		                else 
		                     	begin
			                 	nstate<=nstate; 		       
	                        	end           
                     end
                     
        SEND_READ_MODE_CONFIG: begin                                                         ///logic for trasnmission 8 bit frame ,combination of device ID and RW bit
                                if(scl_low==1'b1 )
                                     	scl_o<=1'b1;
        	             	else
		                 	scl_o<=1'b0;
		             
		              	if(sda_hi_by2==1'b1) 
				begin   
                                     	if(cycle==8) 
					begin
                                      		nstate<=ACK_NACK_4;            
		                                cycle<=4'b0;
		                              	sda_oen<=1'b0;
       	                         	end
                                 	else  
				 	begin    
                                      		sda_o<=device_reg[(DATA_WIDTH-1)-cycle];
                                     		cycle<=cycle+1;
                                      		nstate<=SEND_READ_MODE_CONFIG; 
					end 
                                end
                    	end         
                      
             ACK_NACK_4: begin                                                           ///logic for ack/nack detection of device ID                                                    
                               	if(scl_low==1'b1 )
                                     	scl_o<=1'b1;
        	            	else
		                  	scl_o<=1'b0;

                 		if (sda_i==1'b1 && scl_lo_by2==1'b1)
				    	ack<=1'b1;
			     	else if (sda_i==1'b0 && scl_lo_by2==1'b1)
			     		ack<=1'b0;
				
                  		if(scl_low_neg_edge && ~ack)  //ack
                     		begin 
                         		nstate<=READ_DATA;
                          		ack<=1'b1;
                         		cycle<=4'b0;
                       		end
                    		else if(scl_low_neg_edge && ack) //nack
                         	begin 
                          		nstate<=IDLE;
                          		sda_oen<=1'b1;
                          		ack<=1'b1;
                          		cycle<=4'b0;
                          	end 
                     end 
                                         
           READ_DATA:  begin                                                      ///logic for reading 8 bit data from given memory address 
                              	if(scl_low==1'b1 )
                              		scl_o<=1'b1;
        	          	else
		                      	scl_o<=1'b0;
		                    
		              	if(sda_hi_by2==1'b1) 
				begin   
                                 	if(cycle==8)  
                                 	begin
                                        	nstate<=STOP_READ;            
		                                cycle<=4'b0;
		                               	sda_oen<=1'b1;
		                               	sda_o<=1'b0;
       	                         	end
                          		else          
                         	 	begin    
                                		receive_data_reg[(DATA_WIDTH-1)-cycle]<=sda_i;
                                		cycle<=cycle+1;
                                		nstate<=READ_DATA; 
                                 	end 
                              end
                         end
     
		      
	      STOP_READ: begin                                       //logic for I2C stop condition generation

                                 	scl_o<=1'b1;
		                       	scl_oen<=1'b1;
		       
		                 if (sda_hi_by2==1'b1) 
				 begin 
			               	sda_o<=1'b1;
		       	               	sda_oen<=1'b1;
		                 end 
		        
		              	else if (scl_low_neg_edge==1'b1) 
				begin 
		                      	if(delay_counter==5'd20) 
		                      	begin
		                            	delay_counter<=5'b0;
			                      	nstate<=IDLE;
			            	end
			             	else  
					begin
			                    	delay_counter<=delay_counter+1;
			                     	nstate<=nstate;
			              	end

	                         end     
	                      end              

	             default: nstate<=IDLE;
	         endcase
	        end                                                                        		                                   
       end       
end


assign sdaout=sda_o;
assign sclout=scl_o;
assign receive_read_reg=receive_data_reg;

IOBUF prim_1(.IO(SDA),.O(sda_i),.I(sdaout),.T(~sda_oen));               //bidirection buffer primitives
IOBUF prim_2(.IO(SCL),.O(),.I(sclout),.T(~scl_oen));



endmodule





