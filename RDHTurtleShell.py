#!/usr/bin/env python
# coding: utf-8

from pathlib import Path
from PIL import Image
import sys
import jpeglib
import numpy as np
import pandas as pd

BASE_DIR = Path(__file__).resolve().parents[1]
if str(BASE_DIR) not in sys.path:
    sys.path.append(str(BASE_DIR))

from zigzag import zigzag, inverse_zigzag
import TurtleShell as TurtleShell

STEGO_DIR = BASE_DIR / "stego-images"
RECOVERED_DIR = BASE_DIR / "recovered-images"
KEYS_DIR = BASE_DIR / "keys"

for out_dir in (STEGO_DIR, RECOVERED_DIR, KEYS_DIR):
    out_dir.mkdir(parents=True, exist_ok=True)

def _resolve_input_path(image_path):
    p = Path(image_path)
    if p.is_absolute():
        return str(p)
    return str((BASE_DIR / p).resolve())


def _stego_output_path(image_path):
    return STEGO_DIR / f"stego_{Path(image_path).name}"


def _recovered_output_path(image_path):
    return RECOVERED_DIR / f"recovered_{Path(image_path).name}"


def _key_output_path(image_path):
    return KEYS_DIR / f"key_{Path(image_path).stem}.txt"

scale_factor = 1.0
threshold = 150

_, shells, cell_to_shells = TurtleShell.init(mode="8N")
_, shells_17, cell_to_shells_17 = TurtleShell.init(mode="17N")


mapping_reversibility = {
    0: (0, 0),
    1: (1, 0),
    2: (1, 1),
    3: (0, 1),
    4: (-1, 1),
    5: (-1, 0),
    6: (-1, -1),
    7: (0, -1),
    8: (1, -1),
    9: (0, 0)  
}

key_map_reversibility = {
    (0, 0)   : 0,
    (1, 0)   : 5,
    (1, 1)   : 6,
    (0, 1)   : 7,
    (-1, 1)  : 8,
    (-1, 0)  : 1,
    (-1, -1) : 2,
    (0, -1)  : 3,
    (1, -1)  : 4
}

def map_back_to_ori_coeff(x, y, key):
    ori_x = x + mapping_reversibility[key][0]
    ori_y = y + mapping_reversibility[key][1]
    if ori_x == 0:
        ori_x += mapping_reversibility[key][0]
    if ori_y == 0:
        ori_y += mapping_reversibility[key][1]
    return (ori_x, ori_y)

def read_text_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as file:
        content = file.read()
    return content

def write_text_key_file(list_key, filename):
    with open(filename, 'w') as f:
        for item in list_key:
            f.write("%i " % item)

def read_text_key_file(filename):
    with open(filename, 'r') as f:
        return [int(x) for x in f.read().split() if x]

def convert_data_to_bits(data):
    data = data + '\0'
    data_bin = ''.join(format(ord(c), '08b') for c in data)
    lendata = len(data_bin)
    print(f"Secret Data: {data_bin}")
    print(f"Panjang Bit Secret Data: {len(data_bin)}")
    return data_bin, lendata

def get_qf_from_filename(image_path):
    qf_index = image_path.find("_qf")
    if qf_index != -1:
        qf_value = int(image_path[qf_index + 3 : qf_index + 5])
        return qf_value

def get_quantized_coefficients(image_path):
    im = jpeglib.read_dct(image_path)
    num_v_blocks, num_h_blocks, _, _  = im.Y.shape
    sorted_coeffs = []
    for i in range(num_v_blocks):
        for j in range(num_h_blocks):
            block = im.Y[i, j]
            zigzag_coeffs = zigzag(block)
            sorted_coeffs.append(zigzag_coeffs)
    return sorted_coeffs

def get_nacp(sorted_coefficients):
    valid_nacp = []
    for zigzag_coeff in sorted_coefficients:
        ac_coeffs = zigzag_coeff[1:] # AC coefficients
        non_zero_indices = np.nonzero(np.abs(ac_coeffs) >= 1)[0]
        non_zero_ac = [ac_coeffs[i] for i in non_zero_indices]

        for i in range(0, len(non_zero_ac) - 1, 2):
            x = int(non_zero_ac[i])
            y = int(non_zero_ac[i+1])
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
            else: break
        zigzag_coeff[1:] = ac_coeffs

    return sorted_coefficients

def block_smoothness_estimation(image):
    im = jpeglib.read_dct(image)
    h, w, _, _ = im.Y.shape
    smoothness_block = []
    total_ec = 0
    total_zero_count = 0
    for i in range(h):
        for j in range(w):
            block = im.Y[i, j]
            print( block)
            block_1d = block.flatten()
            block_1d = block_1d[1:]  # AC coefficients 
            zero_count = np.sum(block_1d == 0)
            non_zero_sum = np.sum(abs(block_1d[block_1d != 0]))
            non_zero_indices = np.nonzero(block_1d)[0]
            capable_bits = 4 if zero_count == 0 else 3
            total_ec += len(non_zero_indices) // 2 * capable_bits
            total_zero_count += zero_count
            smoothness_block.append(((i, j), zero_count, non_zero_sum))

    print(f"Total blocks: {h * w}")
    print(f"Total embedding capacity (estimated): {total_ec} bits")
    print(f"Total zero count: {total_zero_count}")
    return total_ec

def block_smoothness(image):
    im = jpeglib.read_dct(image)
    h, w, _, _ = im.Y.shape
    q_table = im.qt[0]
    smoothness_block = []
    smoothness_score = []
    sum_nacp = 0
    for i in range(h):
        for j in range(w):
            block = im.Y[i, j]
            block_1d = block.flatten()[1:]
            ac_block = block.copy()
            ac_block[0, 0] = 0
            z_k = np.sum(ac_block == 0)
            # E_k = np.sum(np.abs(ac_block != 0) * (q_table ** 2))
            E_k = np.sum((q_table ** 2)[ac_block != 0])
            S_k = z_k  + float(z_k / (1 + E_k))
            non_zero_indices = np.nonzero(block_1d)[0][1:]
            sum_nacp += non_zero_indices.size
            smoothness_block.append(((i, j), z_k, E_k, S_k))
            smoothness_score.append(((i, j), S_k))

    mean_score = np.mean([score for _, score in smoothness_score])
    total_ec = sum_nacp // 2 * 3
    return smoothness_block, smoothness_score, mean_score, total_ec

def arrange_ac_in_small_qt_steps(image_path):
    im = jpeglib.read_dct(_resolve_input_path(image_path))
    q_table = im.qt[0]
    zig = zigzag(q_table)
    q_entries = [(i, v) for i, v in enumerate(zig) if i != 0]
    sorted_q_entries = sorted(q_entries, key=lambda x: x[1])
    ordered_idx = [idx for idx, val in sorted_q_entries]
    return sorted_q_entries, ordered_idx

def precompute_block_structure(image_path, smoothness_list, ordered_idx):
    im = jpeglib.read_dct(image_path)
    block_data = []
    total_pairs = 0
    count_both_pair_1 = 0
    count_one_pair_1 = 0
    for (block_i, block_j), _ in smoothness_list:
        block = im.Y[block_i, block_j]
        zz = zigzag(block)
        ac = zz[1:]
        valid_idx = []
        for idx in ordered_idx:
            if idx >= len(ac): continue
            if ac[idx] != 0: valid_idx.append(idx)
        pairs = []
        for i in range(0, len(valid_idx)-1, 2):
            pairs.append((valid_idx[i], valid_idx[i+1]))
            x, y = ac[valid_idx[i]], ac[valid_idx[i+1]]
            if abs(x) == 1 and abs(y) == 1:
                count_both_pair_1 += 1
            elif abs(x) == 1 or abs(y) == 1:
                count_one_pair_1 += 1
        block_data.append({
            "coord": (block_i, block_j),
            "zigzag": zz,
            "pairs": pairs
        })
        total_pairs += len(pairs)
    return block_data, total_pairs, count_both_pair_1, count_one_pair_1

def estimated_max_capacity(total_pairs, count_both_pair_1, count_one_pair_1, data_bin):
    base_capacity = total_pairs * 3
    reduce_capacity = (((5/9) * count_both_pair_1) + ((3/9) * count_one_pair_1)) * 3
    max_capacity = base_capacity - reduce_capacity
    if max_capacity < len(data_bin):
        print(f"Warning: Estimated max capacity {int(max_capacity)} bits is less than data size {len(data_bin)} bits.")
    print(f"Estimated max capacity: {int(max_capacity)} bits")
    return max_capacity

def embed_in_optimized_order(block_data, data_bin):
    t, mode, pair_level = 3, "8N", 0
    lendata = len(data_bin)
    list_key = []
    while lendata > 0:
        progress = False
        for block in block_data:
            if pair_level >= len(block["pairs"]): continue
            i1, i2 = block["pairs"][pair_level]
            ac = block["zigzag"][1:]
            x, y = int(ac[i1]), int(ac[i2])
            key = 0
            bits = data_bin[:t].ljust(t,'0')
            target_val = int(bits,2)
            val_int = TurtleShell.get_hex_matrix_value(x,y,mode=mode)
            if target_val != val_int:
                shell_coords = TurtleShell.get_kxk_nearest_signed(x,y,t)
                new_x, new_y = TurtleShell.find_corresponding_val(shell_coords, target_val, (x,y), mode=mode)
                diff_x = np.abs(new_x - x)
                diff_y = np.abs(new_y - y)
                if diff_x > 1 or diff_y > 1: 
                    key = 9
                    list_key.append(key)
                    progress = True
                    continue # skip embedding
                else: key = key_map_reversibility[(new_x - x, new_y - y)]
                x, y = new_x, new_y
            ac[i1], ac[i2] = x, y
            progress = True
            data_bin = data_bin[t:]
            lendata -= t
            list_key.append(key)
            if lendata <= 0: break

        if not progress:break
        pair_level += 1
    return list_key, block_data 

def extract_in_optimized_order(block_data, key_list):
    t, mode, pair_level = 3, "8N", 0
    pair_level, key_idx = 0, 0
    finish = False
    bitstream = ""
    decoded_text = ""
    while True:
        progress = False
        for block in block_data:
            if finish: break
            if pair_level >= len(block["pairs"]): continue
            i1, i2 = block["pairs"][pair_level]
            ac = block["zigzag"][1:]
            x = int(ac[i1])
            y = int(ac[i2])
            key = key_list[key_idx] if key_idx < len(key_list) else 0
            key_idx += 1
            if key != 9:
                val = TurtleShell.get_hex_matrix_value(x, y, mode=mode)
                bits = format(val, f"0{t}b")
                bitstream += bits
            ac[i1], ac[i2] = map_back_to_ori_coeff(x, y, key)
            block["zigzag"][1:] = ac
            progress = True

            while len(bitstream) >= 8:
                byte = bitstream[:8]
                bitstream = bitstream[8:]
                char_val = int(byte, 2)
                if char_val == 0: 
                    finish = True
                    break
                decoded_text += chr(char_val)

        if not progress: break
        pair_level += 1
    return decoded_text, block_data

def construct_stego_file(image_path, new_coeffs):
    resolved_image_path = _resolve_input_path(image_path)
    im = jpeglib.read_dct(resolved_image_path)
    num_v_blocks, num_h_blocks, v_block_size, h_block_size  = im.Y.shape
    idx = 0

    for i in range(num_v_blocks):
        for j in range(num_h_blocks):
            block_coeffs = new_coeffs[idx]
            block = inverse_zigzag(block_coeffs, v_block_size, h_block_size)
            im.Y[i, j] = block
            idx += 1

    output_path = _stego_output_path(image_path)
    print(f"Image with secret data is saved to {output_path}")
    im.write_dct(str(output_path))
    return str(output_path)

def construct_stego_file_2(image_path, block_data):
    resolved_image_path = _resolve_input_path(image_path)
    im = jpeglib.read_dct(resolved_image_path)
    for block in block_data:
        block_i, block_j = block["coord"]
        new_block = inverse_zigzag(block["zigzag"], im.Y.shape[2], im.Y.shape[3])
        im.Y[block_i, block_j] = new_block
    output_path = _stego_output_path(image_path)
    print(f"Image with secret data is saved to {output_path}")
    im.write_dct(str(output_path))
    return str(output_path)

def construct_recovered_file(image_path, block_data):
    resolved_image_path = _resolve_input_path(image_path)
    im = jpeglib.read_dct(resolved_image_path)
    for block in block_data:
        block_i, block_j = block["coord"]
        new_block = inverse_zigzag(block["zigzag"], 8, 8)
        im.Y[block_i, block_j] = new_block
    output_path = _recovered_output_path(image_path)
    print(f"Recovered image is saved to {output_path}")
    im.write_dct(str(output_path))
    return str(output_path)

def data_hiding_process(secret_data, nacp_coord="", mode="8N"):
    if secret_data == "": return nacp_coord
    bit = 3 if mode == "8N" else 4
    secret_data = secret_data + '\0'
    data_bin = ''.join(format(ord(c), '08b') for c in secret_data)
    lendata = len(data_bin)
    print(f"Secret Data: {secret_data}")
    print(f"Panjang Bit Secret Data: {lendata}")

    decimals = []
    for i in range(0, len(data_bin), bit):
        group = data_bin[i:i+bit].ljust(bit, '0')
        decimals.append(int(group, 2))

    if len(decimals) > len(nacp_coord):
        print("Warning: Not enough NACP coordinates to embed all data.")

    for i in range(len(decimals)):
        x, y = nacp_coord[i]
        if TurtleShell.get_hex_matrix_value(x, y, mode) == decimals[i]:
            nacp_coord[i] = (x, y)
        else:
            shell_coords = TurtleShell.get_kxk_nearest_signed(x, y, bit)
            # _, shell_coords = TurtleShell.get_shell_coords(x, y, shells, cell_to_shells)
            found = TurtleShell.find_corresponding_val(shell_coords, decimals[i], nacp_coord[i], mode)
            nacp_coord[i] = found
    return nacp_coord

def data_hiding_rdh_turtle_shell(image_path, smoothness_list, data_bin):
    resolved_image_path = _resolve_input_path(image_path)
    im = jpeglib.read_dct(resolved_image_path)
    lendata = len(data_bin)
    list_key = []

    for (block_i, block_j), score in smoothness_list:
        if lendata <= 0: break
        # N = 8 if score >= threshold else 17
        N = 8
        t = 3 if N == 8 else 4
        mode = f"{N}N"
        block = im.Y[block_i, block_j]
        zigzag_coeffs = zigzag(block)
        ac_coeffs = zigzag_coeffs[1:]
        non_zero_indices = np.nonzero(np.abs(ac_coeffs) >= 1)[0]
        choosen_shells = shells if N == 8 else shells_17
        choosen_cell_to_shells = cell_to_shells if N == 8 else cell_to_shells_17
        for idx in range(0, len(non_zero_indices) - 1, 2):
            if lendata <= 0: break
            x = int(ac_coeffs[non_zero_indices[idx]])
            y = int(ac_coeffs[non_zero_indices[idx + 1]])
            key = 0
            bits = data_bin[:t].ljust(t, '0') 
            target_val = int(bits, 2)
            val_int = TurtleShell.get_hex_matrix_value(x, y, mode=mode)
            if target_val != val_int:
                shell_coords = TurtleShell.get_kxk_nearest_signed(x, y, t)
                # _, shell_coords = TurtleShell.get_shell_coords(x, y, choosen_shells, choosen_cell_to_shells)
                new_x, new_y = TurtleShell.find_corresponding_val(shell_coords, target_val, (x, y), mode=mode)
                diff_x = np.abs(new_x - x)
                diff_y = np.abs(new_y - y)
                if diff_x > 1 or diff_y > 1: 
                    key = 9
                    list_key.append(key)
                    continue # skip embedding
                else: key = key_map_reversibility[(new_x - x, new_y - y)]
                x, y = new_x, new_y
            ac_coeffs[non_zero_indices[idx]] = float(x)
            ac_coeffs[non_zero_indices[idx + 1]] = float(y)
            data_bin = data_bin[t:]
            lendata -= t
            list_key.append(key)

        zigzag_coeffs[1:] = ac_coeffs
        zigzag_coeffs[0] = block[0, 0]  
        im.Y[block_i, block_j] = inverse_zigzag(zigzag_coeffs, 8, 8)

    save_path = _key_output_path(image_path)
    output_path = _stego_output_path(image_path)
    print(f"Data embedding completed. Stego image saved to {output_path}")
    write_text_key_file(list_key, str(save_path))
    im.write_dct(str(output_path))
    return str(output_path)

def data_hiding_rdh_ts_optimized(image_path, smoothness_list, data_bin, ordered_idx):
    save_key_path = _key_output_path(image_path)
    block_data, total_pairs, count_both_pair_1, count_one_pair_1 = precompute_block_structure(image_path, smoothness_list, ordered_idx)
    max_capacity = estimated_max_capacity(total_pairs, count_both_pair_1, count_one_pair_1, data_bin)
    list_key, modified_block_data = embed_in_optimized_order(block_data, data_bin)
    stego_path = construct_stego_file_2(image_path, modified_block_data)
    write_text_key_file(list_key, str(save_key_path))
    return max_capacity, stego_path

def data_extract_process(nacp_coord, mode="8N"):
    extracted_data = ""
    data_bits = ""

    for i, (x, y) in enumerate(nacp_coord):
        val = TurtleShell.get_hex_matrix_value(x, y, mode=mode)
        bit = 3 if mode == "8N" else 4
        bits = format(val & ((1 << bit) - 1), f'0{bit}b')
        data_bits += bits

        while len(data_bits) >= 8:
            byte = data_bits[:8]
            char_val = int(byte, 2)
            if char_val == 0: # Null terminator ASCII
                return extracted_data
            try:
                char = chr(char_val)
                extracted_data += char
            except:
                return extracted_data
            data_bits = data_bits[8:]

    return extracted_data

def data_extract_rdh_turtle_shell(stego_image_path, list_key, smoothness_list):
    resolved_image_path = _resolve_input_path(stego_image_path)
    im = jpeglib.read_dct(resolved_image_path)
    bitstream = ""
    decoded_text = ""
    key_idx = 0
    finish = False
    for (block_i, block_j), score in smoothness_list:
        # N = 8 if score >= threshold else 17
        N = 8
        t = 3 if N == 8 else 4
        mode = f"{N}N"
        block = im.Y[block_i, block_j]
        zigzag_coeffs = zigzag(block)
        ac_coeffs = zigzag_coeffs[1:]
        non_zero_indices = np.nonzero(np.abs(ac_coeffs) >= 1)[0]

        for idx in range(0, len(non_zero_indices) - 1, 2):
            if finish: break
            x = int(ac_coeffs[non_zero_indices[idx]])
            y = int(ac_coeffs[non_zero_indices[idx + 1]])
            key = list_key[key_idx] if key_idx < len(list_key) else 0
            key_idx += 1
            if key != 9:
                val = TurtleShell.get_hex_matrix_value(x, y, mode=mode)
                bits = format(val, f"0{t}b")
                bitstream += bits
            ac_coeffs[non_zero_indices[idx]], ac_coeffs[non_zero_indices[idx + 1]] = map_back_to_ori_coeff(x, y, key)
            while len(bitstream) >= 8:
                byte = bitstream[:8]
                bitstream = bitstream[8:]
                char_val = int(byte, 2)
                if char_val == 0:   # Null terminator
                    finish = True
                    break
                decoded_text += chr(char_val)

        zigzag_coeffs[1:] = ac_coeffs
        zigzag_coeffs[0] = block[0, 0]  
        im.Y[block_i, block_j] = inverse_zigzag(zigzag_coeffs, 8, 8)

    output_path = _recovered_output_path(stego_image_path)
    print(f"Recovered image saved to {output_path}")
    im.write_dct(str(output_path))
    return decoded_text, str(output_path)

def data_extract_rdh_ts_optimized(image_path, key_list, smoothness_list, ordered_idx):
    block_data, _, _, _ = precompute_block_structure(image_path, smoothness_list, ordered_idx)
    decoded_text, original_block_data = extract_in_optimized_order(block_data, key_list)
    recovered_path = construct_recovered_file(image_path, original_block_data)
    return decoded_text, recovered_path

def compare_spatial_frequency(cover_image_path, stego_image_path):
    cover = np.array(Image.open(cover_image_path).convert('L'), dtype=np.float64)
    stego = np.array(Image.open(stego_image_path).convert('L'), dtype=np.float64)

    spatial_difference = np.abs(cover - stego) ** 2

    cover_freq = get_quantized_coefficients(cover_image_path)
    stego_freq = get_quantized_coefficients(stego_image_path)
    freq_difference = np.array(cover_freq) - np.array(stego_freq)

    return freq_difference, spatial_difference

# Encode 
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

def encode_2(image_path, data, qf):
    image = Image.open(image_path).convert('L')
    stegoimg = image.copy()
    img_arr = np.array(stegoimg)
    q_mat = FD.custom_q_mat(qf)
    sorted_coefficients = FD.transform_to_freq(img_arr, q_mat)
    nacp_coords = get_nacp(sorted_coefficients)
    modified_nacp_coords = data_hiding_process(data, nacp_coords)
    modified_coeffs = replace_nacp(sorted_coefficients, modified_nacp_coords)
    np.save("modified_coefficients.npy", modified_coeffs)

# Proposed Method - RDH Turtle Shell Embedding
def encode_3(image_path, secret_data):
    _, smoothness_score, mean_score, total_ec = block_smoothness(image_path)
    smoothness_list = sorted(smoothness_score, key=lambda x: -x[1])
    data_bin, lendata = convert_data_to_bits(secret_data)
    data_hiding_rdh_turtle_shell(image_path, smoothness_list, data_bin)

# Proposed Method - RDH Turtle Shell Optimized Embedding
def encode_optimized(image_path, secret_data):
    _, ordered_idx = arrange_ac_in_small_qt_steps(image_path)
    _, smoothness_score, _, _ = block_smoothness(image_path)
    smoothness_list = sorted(smoothness_score, key=lambda x: x[1])
    data_bin, _ = convert_data_to_bits(secret_data)
    max_capacity, _ = data_hiding_rdh_ts_optimized(image_path, smoothness_list, data_bin, ordered_idx)
    return max_capacity

def encode_optimized_api(image_path, secret_data):
    _, ordered_idx = arrange_ac_in_small_qt_steps(image_path)
    _, smoothness_score, _, _ = block_smoothness(image_path)
    smoothness_list = sorted(smoothness_score, key=lambda x: x[1])
    data_bin, _ = convert_data_to_bits(secret_data)
    max_capacity, stego_path = data_hiding_rdh_ts_optimized(image_path, smoothness_list, data_bin, ordered_idx)
    return int(max_capacity), stego_path

# Decode
def decode(stego_image_path):
    sorted_coeffs = get_quantized_coefficients(stego_image_path)
    nacp_coords = get_nacp(sorted_coeffs)
    print(nacp_coords)
    extracted_data = data_extract_process(nacp_coords, mode="8N")
    return extracted_data

def decode_api(stego_image_path):
    sorted_coeffs = get_quantized_coefficients(stego_image_path)
    nacp_coords = get_nacp(sorted_coeffs)
    extracted_data = data_extract_process(nacp_coords, mode="8N")
    return extracted_data

def decode_2(stego_file):
    modified_coeffs = np.load(stego_file, allow_pickle=True)
    nacp_coords = get_nacp(modified_coeffs)
    extracted_data = data_extract_process(nacp_coords)
    return extracted_data

# Proposed Method - RDH Turtle Shell Embedding
def decode_3(stego_image_path):
    _, smoothness_score, mean_score, total_ec = block_smoothness(stego_image_path)
    smoothness_list = sorted(smoothness_score, key=lambda x: -x[1])
    base_name = stego_image_path.split("/")[-1].split(".")[0][6:]  
    key_list = read_text_key_file(str(KEYS_DIR / f"key_{base_name}.txt"))
    decoded_text, _ = data_extract_rdh_turtle_shell(stego_image_path, key_list, smoothness_list)
    return decoded_text

# Proposed Method - RDH Turtle Shell Optimized Embedding
def decode_optimized(stego_image_path):
    _, ordered_idx = arrange_ac_in_small_qt_steps(stego_image_path)
    _, smoothness_score, _, _ = block_smoothness(stego_image_path)
    smoothness_list = sorted(smoothness_score, key=lambda x: x[1])
    base_name = stego_image_path.split("/")[-1].split(".")[0][6:]  
    key_list = read_text_key_file(str(KEYS_DIR / f"key_{base_name}.txt"))
    decoded_text, _ = data_extract_rdh_ts_optimized(stego_image_path, key_list, smoothness_list, ordered_idx)
    return decoded_text


def decode_optimized_api(stego_image_path):
    _, ordered_idx = arrange_ac_in_small_qt_steps(stego_image_path)
    _, smoothness_score, _, _ = block_smoothness(stego_image_path)
    smoothness_list = sorted(smoothness_score, key=lambda x: x[1])
    base_name = Path(stego_image_path).stem[6:]
    key_list = read_text_key_file(str(KEYS_DIR / f"key_{base_name}.txt"))
    decoded_text, recovered_path = data_extract_rdh_ts_optimized(stego_image_path, key_list, smoothness_list, ordered_idx)
    return decoded_text, recovered_path