#!/usr/bin/python

import sys

def hex_to_comma_list(hex_mask):
    binary = bin(int(hex_mask, 16))[2:]
    reversed_binary = binary[::-1]
    i = 0
    output = ""
    for bit in reversed_binary:
        if bit == '1':
            output = output + str(i) + ','
        i = i + 1
    return output[:-1]

def comma_list_to_hex(cpus):
    cpu_arr = cpus.split(",")
    binary_mask = 0
    for cpu in cpu_arr:
        binary_mask = binary_mask | (1 << int(cpu))
    return format(binary_mask, '02x')

if len(sys.argv) != 2:
    print ("Please provide a hex CPU mask or comma separated CPU list")
    sys.exit(2)

user_input = sys.argv[1]

try:
    print(hex_to_comma_list(user_input))
except:
    print(comma_list_to_hex(user_input))
