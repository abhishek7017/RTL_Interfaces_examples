# 24LC04 EEPROM Interface Controller

## Overview

This project implements a Verilog RTL controller for interfacing with a 24LC04 EEPROM using the I²C protocol. The design provides a simple transaction-level interface where the user supplies the EEPROM device ID, memory address, and write data through input ports. The controller automatically handles the complete I²C communication sequence required for EEPROM read and write operations.

The I²C clock frequency is configurable through parameters, allowing the design to be adapted to different system clock frequencies and bus speed requirements.

## Features

* Verilog HDL implementation
* 24LC04 EEPROM support
* Byte read operation
* Byte write operation
* 7-bit I²C addressing
* Configurable I²C clock frequency
* START and STOP condition generation
* ACK/NACK handling
* FSM-based transaction control
* Hardware-validated implementation

## Interface

### Inputs

| Signal    | Description                  |
| --------- | ---------------------------- |
| clk       | System clock                 |
| rst_n     | Active-low reset             |
| start     | Initiates EEPROM transaction |
| rw        | Read/Write control           |
| device_id | EEPROM device address        |
| mem_addr  | EEPROM memory location       |
| wr_data   | Data to be written to EEPROM |

### Outputs

| Signal    | Description                                 |
| --------- | ------------------------------------------- |
| rd_data   | Data read from EEPROM                       |
| scl       | I²C serial clock output                     |
| sda       | I²C serial data line                        |

## Write Operation

The controller performs the following sequence:

START
→ Device Address + Write Bit
→ ACK
→ Memory Address
→ ACK
→ Data Byte
→ ACK
→ STOP

## Read Operation

The controller performs the following sequence:

START
→ Device Address + Write Bit
→ ACK
→ Memory Address
→ ACK
→ Repeated START
→ Device Address + Read Bit
→ ACK
→ Read Data Byte
→ NACK
→ STOP

The received data is made available on the `rd_data` output.

## Hardware Validation

The design has been validated on FPGA hardware by interfacing with a physical 24LC04 EEPROM device and successfully performing EEPROM read and write operations.

## Applications

* Non-volatile data storage
* Configuration parameter storage
* Embedded FPGA systems
* I²C peripheral interfacing
* Learning and reference design for EEPROM communication
