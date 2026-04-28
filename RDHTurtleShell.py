#!/usr/bin/env python
# coding: utf-8

from pathlib import Path
import sys

import jpeglib
import numpy as np

BASE_DIR = Path(__file__).resolve().parents[1]
if str(BASE_DIR) not in sys.path:
    sys.path.append(str(BASE_DIR))

from zigzag import zigzag, inverse_zigzag
import TurtleShell as TurtleShell

STEGO_DIR = BASE_DIR / "stego-images"
STEGO_DIR.mkdir(parents=True, exist_ok=True)


def _resolve_input_path(image_path):
    p = Path(image_path)
    if p.is_absolute():
        return str(p)
    return str((BASE_DIR / p).resolve())


def _stego_output_path(image_path):
    return STEGO_DIR / f"stego_{Path(image_path).name}"


def get_quantized_coefficients(image_path):
    im = jpeglib.read_dct(_resolve_input_path(image_path))
    num_v_blocks, num_h_blocks, _, _ = im.Y.shape
    sorted_coeffs = []
    for i in range(num_v_blocks):
        for j in range(num_h_blocks):
            sorted_coeffs.append(zigzag(im.Y[i, j]))
    return sorted_coeffs


def get_nacp(sorted_coefficients):
    valid_nacp = []
    for zigzag_coeff in sorted_coefficients:
        ac_coeffs = zigzag_coeff[1:]
        non_zero_indices = np.nonzero(np.abs(ac_coeffs) >= 1)[0]
        non_zero_ac = [ac_coeffs[i] for i in non_zero_indices]

        for i in range(0, len(non_zero_ac) - 1, 2):
            x = int(non_zero_ac[i])
            y = int(non_zero_ac[i + 1])
            if x != 0 and y != 0:
                valid_nacp.append((x, y))

    return valid_nacp


def replace_nacp(sorted_coefficients, nacp_coords):
    pair_index = 0

    for zigzag_coeff in sorted_coefficients:
        ac_coeffs = zigzag_coeff[1:]
        non_zero_indices = np.nonzero(np.abs(ac_coeffs) >= 1)[0]
        non_zero_ac = [ac_coeffs[i] for i in non_zero_indices]

        for idx in range(0, len(non_zero_ac) - 1, 2):
            if pair_index < len(nacp_coords):
                new_x, new_y = nacp_coords[pair_index]
                i1, i2 = non_zero_indices[idx], non_zero_indices[idx + 1]
                ac_coeffs[i1] = float(new_x)
                ac_coeffs[i2] = float(new_y)
                pair_index += 1
            else:
                break
        zigzag_coeff[1:] = ac_coeffs

    return sorted_coefficients


def construct_stego_file(image_path, new_coeffs):
    resolved_image_path = _resolve_input_path(image_path)
    im = jpeglib.read_dct(resolved_image_path)
    num_v_blocks, num_h_blocks, v_block_size, h_block_size = im.Y.shape
    idx = 0

    for i in range(num_v_blocks):
        for j in range(num_h_blocks):
            block = inverse_zigzag(new_coeffs[idx], v_block_size, h_block_size)
            im.Y[i, j] = block
            idx += 1

    output_path = _stego_output_path(image_path)
    print(f"Image with secret data is saved to {output_path}")
    im.write_dct(str(output_path))
    return str(output_path)


def data_hiding_process(secret_data, nacp_coord="", mode="8N"):
    if secret_data == "":
        return nacp_coord

    bit = 3 if mode == "8N" else 4
    secret_data = secret_data + "\0"
    data_bin = "".join(format(ord(c), "08b") for c in secret_data)

    decimals = []
    for i in range(0, len(data_bin), bit):
        group = data_bin[i:i + bit].ljust(bit, "0")
        decimals.append(int(group, 2))

    if len(decimals) > len(nacp_coord):
        print("Warning: Not enough NACP coordinates to embed all data.")

    for i in range(len(decimals)):
        x, y = nacp_coord[i]
        if TurtleShell.get_hex_matrix_value(x, y, mode) == decimals[i]:
            nacp_coord[i] = (x, y)
        else:
            shell_coords = TurtleShell.get_kxk_nearest_signed(x, y, bit)
            nacp_coord[i] = TurtleShell.find_corresponding_val(
                shell_coords,
                decimals[i],
                nacp_coord[i],
                mode,
            )
    return nacp_coord


def data_extract_process(nacp_coord, mode="8N"):
    extracted_data = ""
    data_bits = ""

    for x, y in nacp_coord:
        val = TurtleShell.get_hex_matrix_value(x, y, mode=mode)
        bit = 3 if mode == "8N" else 4
        bits = format(val & ((1 << bit) - 1), f"0{bit}b")
        data_bits += bits

        while len(data_bits) >= 8:
            byte = data_bits[:8]
            char_val = int(byte, 2)
            if char_val == 0:
                return extracted_data
            try:
                extracted_data += chr(char_val)
            except Exception:
                return extracted_data
            data_bits = data_bits[8:]

    return extracted_data


def encode(image_path, message_bits):
    sorted_coeffs = get_quantized_coefficients(image_path)
    nacp_coords = get_nacp(sorted_coeffs)
    print(nacp_coords)
    print(f"NACP Length: {len(nacp_coords)}")
    print(f"Total EC: {len(nacp_coords * 3)}")
    modified_nacp_coords = data_hiding_process(message_bits, nacp_coords, mode="8N")
    modified_coeffs = replace_nacp(sorted_coeffs, modified_nacp_coords)
    print(modified_nacp_coords)
    construct_stego_file(image_path, modified_coeffs)
    print("Data embedding completed.")


def encode_api(image_path, message_bits):
    sorted_coeffs = get_quantized_coefficients(image_path)
    nacp_coords = get_nacp(sorted_coeffs)
    modified_nacp_coords = data_hiding_process(message_bits, nacp_coords, mode="8N")
    modified_coeffs = replace_nacp(sorted_coeffs, modified_nacp_coords)
    stego_path = construct_stego_file(image_path, modified_coeffs)
    return str(stego_path)


def decode(stego_image_path):
    sorted_coeffs = get_quantized_coefficients(stego_image_path)
    nacp_coords = get_nacp(sorted_coeffs)
    print(nacp_coords)
    return data_extract_process(nacp_coords, mode="8N")


def decode_api(stego_image_path):
    sorted_coeffs = get_quantized_coefficients(stego_image_path)
    nacp_coords = get_nacp(sorted_coeffs)
    return data_extract_process(nacp_coords, mode="8N")