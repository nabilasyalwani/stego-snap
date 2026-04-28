#!/usr/bin/env python
# coding: utf-8

from collections import defaultdict
from matplotlib.pylab import ceil, floor
import numpy as np

np.set_printoptions(suppress=True)

# Configuration for Turtle Shell
# 8N : 8-ary (0-7) 3 bits per nacp
# 17N: 17-ary (0-16) 4 bits per nacp

HEX_DIRS_8N = [(1, 0), (-1, 0), (0, 1), (0, -2), (1, -1), (-1, -1)]
BACK_DIRS_8N = [(0, 0), (0, -1)]

HEX_DIRS_17N = [(0, 1), (2, 0), (-2, 0), (-2, -1), (2, -1), (-2, -2), (2, -2), (0, -3)]
BACK_DIRS_17N = [(1, 0), (-1, 0), (0, 0), (-1, -1), (0, -1), (1, -1), (-1, -2), (0, -2), (1, -2)]

TS = {
    "8N": {"n": 1, "n1": 2, "n2": 3, "step": 4, "mod_row": 2, 'offset': 2, 'ceil_log2n': 3, 'hex_dirs': HEX_DIRS_8N, 'back_dirs': BACK_DIRS_8N},
    "17N": {"n": 2, "n1": 3, "n2": 5, "step": 6, "mod_row": 4, 'offset': 3, 'ceil_log2n': 5, 'hex_dirs': HEX_DIRS_17N, 'back_dirs': BACK_DIRS_17N},
}

def turtle_shell_matrix(n, n1, n2):
    rows, cols = 8, 8
    p1 = 1 / (1 + n)
    p2 = n / (1 + n)

    sigma_n2 = 0
    for i in range(1, n + 1):
        sigma_n2 += (n2)  

    mod = (2 * n1 + sigma_n2 + 1)
    matrix = np.zeros((rows, cols), dtype=np.float64)
    for i in range(rows):
      for j in range(cols):
        matrix[i][j] = (i + (ceil(p1 * (j)) * n1) + (floor(p2 * (j)) * n2)) % (mod)

    print(n, n1, n2, p1, p2, sigma_n2, mod)
    print("----")
    print(matrix)
    print("====")
    return matrix

def get_hex_matrix_value(x, y, mode="8N"):
    n, n1, n2 = TS[mode]["n"], TS[mode]["n1"], TS[mode]["n2"]

    p1 = 1 / (1 + n)
    p2 = n / (1 + n)

    sigma_n2 = 0
    for i in range(1, n + 1):
        sigma_n2 += (n2)  

    mod = (2 * n1 + sigma_n2 + 1)

    if (x >= 1 and x <= 1016) and (y >= 1 and y <= 1016):
        val = ((x-1) + (ceil(p1 * (y-1)) * n1) + (floor(p2 * (y-1)) * n2)) % mod
    elif (x >= 1 and x <= 1016) and (y <= -1 and y >= -1024):
        val = ((x-1) + (ceil(p1 * (y)) * n1) + (floor(p2 * (y)) * n2)) % mod
    elif (x <= -1 and x >= -1024) and (y >= 1 and y <= 1016):
        val = ((x) + (ceil(p1 * (y-1)) * n1) + (floor(p2 * (y-1)) * n2)) % mod
    elif (x <= -1 and x >= -1024) and (y <= -1 and y >= -1024):
        val = ((x) + (ceil(p1 * (y)) * n1) + (floor(p2 * (y)) * n2)) % mod
    elif x == 0 or y == 0:
        val = -1

    return int(val)

def generate_shell_centers(x_min, x_max, y_min, y_max, max_val=1016, min_val=-1024, mode='8N'):
    shell_rule = TS[mode]    
    step, mod_row, offset = shell_rule['step'], shell_rule['mod_row'], shell_rule['offset'] 

    row = 0
    centers = []

    for cx in range(x_min, x_max):
        if row % mod_row == 0:
            y_start = y_min
        elif row % mod_row == mod_row / 2:
            y_start = y_min + offset
        else:
            row += 1
            continue

        for cy in range(y_start, y_max, step):
            if (cx == min_val or cx == max_val) or (cy == min_val or cy == max_val):
                continue
            centers.append((cx, cy))
        row += 1

    return centers

def build_shell(center, mode='8N'):
    cx, cy = center
    shell = []

    for dx, dy in TS[mode]['hex_dirs']:
        new_x = cx + dx
        new_y = cy + dy
        new_x = new_x + 1 if new_x >= 0 else new_x
        new_y = new_y + 1 if new_y >= 0 else new_y
        if new_x == 0 or new_y == 0: continue
        shell.append((new_x, new_y))

    for dx, dy in TS[mode]['back_dirs']:
        new_x = cx + dx
        new_y = cy + dy
        new_x = new_x + 1 if new_x >= 0 else new_x
        new_y = new_y + 1 if new_y >= 0 else new_y
        if new_x == 0 or new_y == 0: continue        
        shell.append((new_x, new_y))

    return shell

def classify_cell(x, y, shells):
    shells_here = shells.get((x, y), [])

    if len(shells_here) == 0:
        return "outside", []
    elif len(shells_here) == 1:
        return "back", shells_here
    else:
        return "edge", shells_here
    
def get_shell_coords(x, y, shells, cell_to_shells):
    status, sids = classify_cell(x, y, cell_to_shells)
    coords = set()
    for sid in sids:
        coords.update(shells[sid])

    return status, list(coords)

def find_corresponding_val(coord_candidate, val, nacp_pair, mode="8N"):
    eligible_coords = []
    nearest_coord = None
    min_distance = float('inf')

    for coord in coord_candidate:
        x, y = coord
        if get_hex_matrix_value(x, y, mode) == val:
            eligible_coords.append(coord)
    for coord in eligible_coords:
        x, y = coord
        distance = np.sqrt((x - nacp_pair[0])**2 + (y - nacp_pair[1])**2)
        if distance < min_distance:
            min_distance = distance
            nearest_coord = coord

    return nearest_coord

def get_kxk_nearest_signed(cx, cy, k, min_val=-1024, max_val=1016):
    r = k // 2

    # domain limits
    x_min = cx - r 
    x_max = cx + r + 1
    y_min = cy - r 
    y_max = cy + r + 1

    # boundary shift 
    if x_min < min_val:
        shift = min_val - x_min
        x_min += shift
        x_max += shift
    elif x_max > max_val:
        shift = x_max - max_val
        x_min -= shift
        x_max -= shift

    if y_min < min_val:
        shift = min_val - y_min
        y_min += shift
        y_max += shift
    elif y_max > max_val:
        shift = y_max - max_val
        y_min -= shift
        y_max -= shift

    if 0 in range(x_min, x_max):
        if cx > 0: x_min = x_min - 1
        elif cx < 0: x_max = x_max + 1  
    if 0 in range(y_min, y_max):
        if cy > 0: y_min = y_min - 1
        elif cy < 0: y_max = y_max + 1 

    neighbors = []
    for x in range(x_min, x_max):
        for y in range(y_min, y_max):
            # skip zero axis
            if x == 0 or y == 0: continue
            neighbors.append((x, y))

    return neighbors

def get_kxk_nearest_zero(cx, cy, k, min_val=-1024, max_val=1016):
    r = k // 2

    # domain limits
    x_min = cx - r
    x_max = cx + r + 1
    y_min = cy - r
    y_max = cy + r + 1

    # boundary shift 
    if x_min < min_val:
        shift = min_val - x_min
        x_min += shift
        x_max += shift
    elif x_max > max_val:
        shift = x_max - max_val
        x_min -= shift
        x_max -= shift

    if y_min < min_val:
        shift = min_val - y_min
        y_min += shift
        y_max += shift
    elif y_max > max_val:
        shift = y_max - max_val
        y_min -= shift
        y_max -= shift

    neighbors = []
    for x in range(x_min, x_max):
        for y in range(y_min, y_max):
            neighbors.append((x, y))

    return neighbors

def is_in_central_shell(d1, d2, mode="8N"):
    k = 3 if mode == "8N" else 5
    if (d1, d2) in get_kxk_nearest_zero(0, 0, k=k):
        return True
    return False


def get_zero_matrix_value(x, y, mode="8N"):
    n, n1, n2 = TS[mode]["n"], TS[mode]["n1"], TS[mode]["n2"]
    p1 = 1 / (1 + n)
    p2 = n / (1 + n)
    sigma_n2 = 0
    for i in range(1, n + 1):
        sigma_n2 += (n2)  
    mod = (2 * n1 + sigma_n2 + 1)
    val = ((x) + (ceil(p1 * (y)) * n1) + (floor(p2 * (y)) * n2)) % mod
    return int(val)

def find_val_from_zero(coord_candidate, val, nacp_pair, mode="8N"):
    eligible_coords = []
    nearest_coord = None
    min_distance = float('inf')

    for coord in coord_candidate:
        x, y = coord
        if get_zero_matrix_value(x, y, mode) == val:
            eligible_coords.append(coord)
    for coord in eligible_coords:
        x, y = coord
        distance = np.sqrt((x - nacp_pair[0])**2 + (y - nacp_pair[1])**2)
        if distance < min_distance:
            min_distance = distance
            nearest_coord = coord

    return nearest_coord

def init(mode='8N'):
    if mode=='17N':
        x_min, x_max = -1020, 1014
        y_min, y_max = -1020, 1014
    else:
        x_min, x_max = -1024, 1016
        y_min, y_max = -1024, 1016

    centers = generate_shell_centers(x_min=x_min, x_max=x_max, y_min=y_min, y_max=y_max, mode=mode)

    shells = {}
    shell_id = 0
    for center in centers:
        shell = build_shell(center, mode=mode)
        shells[shell_id] = shell
        shell_id += 1

    cell_to_shells = defaultdict(list)
    for shell_id, shell_coords in shells.items():
        for coord in shell_coords:
            cell_to_shells[coord].append(shell_id)

    return centers, shells, cell_to_shells

def testing(mode='8N'):
    centers, shells, cell_to_shells = init(mode=mode)
    print("Total centers:", len(centers))
    test_points = [(i, j) for i in range(-1024, -1020) for j in range(-1024, -1020)]
    for p in test_points:
        x, y = p
        status, shell_coords = get_shell_coords(x, y, shells, cell_to_shells)
        if (status == "outside") and (x != 0 and y != 0):
            shell_coords = get_kxk_nearest_signed(x, y, TS[mode]['ceil_log2n'])
        print(p, "→", status, ", neighbor count =", len(shell_coords), ", shells candidates:", shell_coords)

def testing2():    
    bit = 3
    target = 2
    mode = "8N" if bit == 3 else "17N"
    neighbors = get_kxk_nearest_zero(0, 0, bit)
    print(f"Neighbors count: {len(neighbors)}")
    print(f"Neighbors: {neighbors}")
    for nx, ny in neighbors:
        # print(f"Coord: ({nx}, {ny})")
        res = get_zero_matrix_value(nx, ny, mode=mode)
        print(f"Coord: ({nx}, {ny}) => Value: {res}")
        if res == target:
            print(f"Found target {target} at coord ({nx}, {ny})")
        else: 
            x, y = find_val_from_zero(neighbors, target, (nx, ny), mode=mode)
            print(f"Corresponding coord for target {target} from ({nx}, {ny}) is ({x}, {y})")