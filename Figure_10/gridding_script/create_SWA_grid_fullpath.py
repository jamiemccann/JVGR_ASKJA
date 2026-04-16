import os
import time
from multiprocessing import Pool, cpu_count

import numpy as np
import pandas as pd
import pyproj
from geopy.distance import geodesic
from geopy.point import Point

# ------------ PARAMETER DEFINITIONS (edit below as needed) ------------

# Input splitting file
DATA_DIR = '../../Data/splitting_data/used'
splitting_file = os.path.join(DATA_DIR, 'ACl_FILTERED_DATA_04.csv')

# Grid parameters for Krafla region
ref_lon = -17.6  # Reference longitude (will be origin in UTM)
ref_lat = 64.5   # Reference latitude (will be origin in UTM)
width = 90.0     # Grid width in km
height = 120.0   # Grid height in km
x_inc = 2      # X grid spacing in km
y_inc = 2      # Y grid spacing in km

# Path tracing and weighting parameters
node_spacing = 0.25  # Path node spacing in km
weighting_mode = 3   # 1=equal, 2=1/d, 3=1/d^2

# Multiprocessing parameters
num_processes = 15    # Set number of CPU cores, or None to use all available

# ----------------------------------------------------------------------

def create_geo_grid(ref_lon, ref_lat, width, height, x_inc, y_inc):
    """
    Creates a regular grid with specified dimensions and spacing.

    Parameters
    ----------
    ref_lon, ref_lat : float
        Reference point coordinates in geographic coordinates (will be origin in UTM)
    width, height : float
        Grid dimensions in kilometers
    x_inc, y_inc : float
        Grid spacing in kilometers for x and y directions

    Returns
    -------
    x_coords, y_coords : arrays
        Arrays containing grid node coordinates in UTM
    grid_cells : dict
        Dictionary containing nodes in each cell
    transformer : pyproj.Transformer
        Coordinate transformer between geographic and UTM
    """

    print("Creating geographical grid...")

    # Define coordinate reference systems
    wgs84 = pyproj.CRS('EPSG:4326')  # WGS84 geographic
    utm28n = pyproj.CRS('EPSG:32628')  # UTM zone 28N

    # Create transformer
    transformer = pyproj.Transformer.from_crs(wgs84, utm28n, always_xy=True)

    # Transform reference point to UTM - this will be the origin (bottom left)
    ref_x, ref_y = transformer.transform(ref_lon, ref_lat)

    # Create grid coordinates with reference point as origin
    x_coords = np.arange(0, width + x_inc, x_inc) * 1000  # Convert to meters
    y_coords = np.arange(0, height + y_inc, y_inc) * 1000  # Convert to meters

    # Create 2D grid
    x_coords, y_coords = np.meshgrid(x_coords, y_coords, indexing="ij")

    # Shift grid to start at reference point
    x_coords += ref_x
    y_coords += ref_y

    # Initialize dictionary to store nodes in each cell
    nx = len(x_coords)
    ny = len(y_coords[0])
    grid_cells = {}
    for i in range(nx - 1):
        for j in range(ny - 1):
            cell_id = f"{i}_{j}"
            grid_cells[cell_id] = []

    print(f"Grid created with {nx}x{ny} points")

    # Calculate grid range in lat/lon
    inv_transformer = pyproj.Transformer.from_crs(utm28n, wgs84, always_xy=True)
    min_lon, min_lat = inv_transformer.transform(x_coords.min(), y_coords.min())
    max_lon, max_lat = inv_transformer.transform(x_coords.max(), y_coords.max())
    print(f"Grid range - Lat: {min_lat:.2f} to {max_lat:.2f}, Lon: {min_lon:.2f} to {max_lon:.2f}")

    return x_coords, y_coords, grid_cells, transformer

def get_path_nodes(start_lat, start_lon, end_lat, end_lon, node_spacing, transformer, weighting_mode=1):
    """
    Gets evenly spaced nodes along great circle path
    
    Parameters
    ----------
    start_lat, start_lon : float
        Starting point coordinates in geographic coordinates
    end_lat, end_lon : float
        Ending point coordinates in geographic coordinates
    node_spacing : float
        Spacing between nodes in kilometers
    transformer : pyproj.Transformer
        Coordinate transformer between geographic and UTM
    weighting_mode : int
        1 for equal weighting
        2 for 1/d distance-based weighting
        3 for 1/d^2 distance-based weighting
        
    Returns
    -------
    node_x, node_y, weights : arrays
        Arrays containing node coordinates in UTM and weights
    """
    
    # Calculate points along great circle path
    start = Point(start_lat, start_lon)
    end = Point(end_lat, end_lon)
    
    d = geodesic(start, end).kilometers
    num_nodes = int(np.ceil(d / node_spacing)) + 1
    distances = np.linspace(0, d, num_nodes)
    
    node_x = []
    node_y = []
    weights = []
    
    # Calculate initial bearing (azimuth)
    y = np.sin(np.radians(end_lon - start_lon)) * np.cos(np.radians(end_lat))
    x = np.cos(np.radians(start_lat)) * np.sin(np.radians(end_lat)) - \
        np.sin(np.radians(start_lat)) * np.cos(np.radians(end_lat)) * \
        np.cos(np.radians(end_lon - start_lon))
    initial_bearing = np.degrees(np.arctan2(y, x))
    
    for dist in distances:
        point = geodesic(kilometers=dist).destination(start, initial_bearing)
        # Transform to UTM - note longitude comes first for pyproj
        x, y = transformer.transform(point.longitude, point.latitude)
        node_x.append(x)
        node_y.append(y)
        
        # Calculate weight based on mode
        if weighting_mode == 1:
            weights.append(1.0)
        else:
            # Calculate distance remaining to station (end point)
            # dist is distance traveled from earthquake, so distance to station = d - dist
            dist_to_station = d - dist
            # Use minimum distance threshold to avoid division by zero and ensure
            # highest weight at station (when dist_to_station = 0)
            min_dist = 0.05
            dist_to_station = max(dist_to_station, min_dist)
            
            if weighting_mode == 2:
                # Weight inversely proportional to distance from station: 1/distance
                weights.append(1.0 / dist_to_station)
            elif weighting_mode == 3:
                # Weight inversely proportional to squared distance from station: 1/distance^2
                weights.append(1.0 / (dist_to_station * dist_to_station))
            
    return np.array(node_x), np.array(node_y), np.array(weights)

def process_single_row(args):
    """
    Worker function to process a single event-station pair.
    Returns a list of (cell_id, node_data) tuples for nodes that should be assigned.
    
    Parameters
    ----------
    args : tuple
        (row_dict, x_coords_1d, y_coords_1d, x_coords_shape, y_coords_shape, 
         node_spacing, weighting_mode)
        
    Returns
    -------
    list : List of (cell_id, (x, y, swa_source_to_station, tlag, weight)) tuples
    """
    (row_dict, x_coords_1d, y_coords_1d, x_coords_shape, y_coords_shape,
     node_spacing, weighting_mode) = args
    
    # Create transformer in worker (pyproj transformers are picklable but safer to recreate)
    wgs84 = pyproj.CRS('EPSG:4326')
    utm28n = pyproj.CRS('EPSG:32628')
    transformer = pyproj.Transformer.from_crs(wgs84, utm28n, always_xy=True)

    # Get path nodes
    node_x, node_y, weights = get_path_nodes(
        row_dict['evla'], row_dict['evlo'],
        row_dict['slat'], row_dict['slon'],
        node_spacing, transformer, weighting_mode
    )
    
    # Assign nodes to grid cells
    results = []
    swa_source_to_station = row_dict['SWA_source_to_station']
    tlag = row_dict['tlag']
    
    for x, y, weight in zip(node_x, node_y, weights):
        # Find grid cell indices using 1D arrays
        i = np.searchsorted(x_coords_1d, x) - 1
        j = np.searchsorted(y_coords_1d, y) - 1
        
        if (i >= 0 and i < x_coords_shape[0] - 1 and 
            j >= 0 and j < y_coords_shape[1] - 1):
            cell_id = f"{i}_{j}"
            results.append((cell_id, (x, y, swa_source_to_station, tlag, weight)))
    
    return results

def calculate_geometric_mean(values, weights):
    """
    Calculate the weighted geometric mean of the given values.

    Parameters
    ----------
    values : array-like
        The SWA_source_to_station percentage values.
    weights : array-like
        The weights corresponding to each value.

    Returns
    -------
    float
        The weighted geometric mean.
    """
    values = np.array(values)
    weights = np.array(weights)
    # Ensure positive values for geometric mean
    values = np.where(values <= 0, 1e-10, values)
    return np.exp(np.sum(weights * np.log(values)) / np.sum(weights))

def main():
    start_time = time.time()
    print("Starting gridding process...")

    # ---- This section uses parameters defined at script top ----
    input_file = splitting_file
    
    # ---- Filename building logic ----
    # Make all output file names include the base input file and grid spacing parameters and weighting mode
    input_base = os.path.splitext(os.path.basename(input_file))[0]
    grid_spacename = f"xinc{x_inc}km_yinc{y_inc}km"

    # Give a human-readable name for the weighting mode
    weighting_mode_names = {
        1: "equal",
        2: "inv_dist",
        3: "inv_dist2"
    }
    weighting_regime = weighting_mode_names.get(weighting_mode, f"mode{weighting_mode}")
    weighting_str = f"weighting_{weighting_regime}"

    # Common prefix including the weighting regime
    common_prefix = f"{input_base}_{grid_spacename}_{weighting_str}"

    # Create a results directory with the common prefix if it doesn't exist
    results_dir = common_prefix
    os.makedirs(results_dir, exist_ok=True)

    # Update all output filenames to be inside the results folder
    grid_nodes_filename = os.path.join(results_dir, f"{common_prefix}_grid_nodes.txt")
    grid_cells_averages_filename = os.path.join(
        results_dir, f"{common_prefix}_grid_cells_SWA_source_to_station_averages.txt"
    )
    grid_xyz_filename = os.path.join(results_dir, f"{common_prefix}_grid.xyz")
    # ---------------------------------

    # Read event-station pairs from CSV
    print("Reading input data...")
    df = pd.read_csv(input_file)
    # Drop rows with missing required values
    required_cols = ['evla', 'evlo', 'slat', 'slon', 'SWA_source_to_station', 'tlag']
    df = df.dropna(subset=required_cols)
    
    print(f"Found {len(df)} event-station pairs")
    print(f"Event data range - Lat: {df['evla'].min():.2f} to {df['evla'].max():.2f}, Lon: {df['evlo'].min():.2f} to {df['evlo'].max():.2f}")
    print(f"Station data range - Lat: {df['slat'].min():.2f} to {df['slat'].max():.2f}, Lon: {df['slon'].min():.2f} to {df['slon'].max():.2f}")

    # Create grid
    x_coords, y_coords, grid_cells, transformer = create_geo_grid(
        ref_lon, ref_lat, width, height, x_inc, y_inc
    )

    # Process each event-station pair using multiprocessing
    print("Processing event-station pairs...")
    
    # Prepare data for multiprocessing
    # Extract 1D coordinate arrays for efficient searching
    x_coords_1d = x_coords[:, 0]
    y_coords_1d = y_coords[0, :]
    x_coords_shape = x_coords.shape
    y_coords_shape = y_coords.shape
    
    # Convert dataframe rows to list of dictionaries for pickling
    rows_data = [row.to_dict() for _, row in df.iterrows()]
    
    # Prepare arguments for worker function
    worker_args = [
        (row_dict, x_coords_1d, y_coords_1d, x_coords_shape, y_coords_shape,
         node_spacing, weighting_mode)
        for row_dict in rows_data
    ]
    
    # Use specified number of processes, or all available if None
    proc_count = num_processes
    if proc_count is None:
        proc_count = cpu_count()
    print(f"Using {proc_count} processes for parallel processing...")
    
    # Process in parallel
    nodes_assigned = 0
    with Pool(processes=proc_count) as pool:
        # Use imap for progress tracking
        results = []
        for i, result in enumerate(pool.imap(process_single_row, worker_args, chunksize=100)):
            results.append(result)
            nodes_assigned += len(result)
            if (i + 1) % 1000 == 0:
                print(f"Processed {i+1}/{len(worker_args)} pairs ({nodes_assigned} nodes assigned)")
    
    # Merge results into grid_cells
    print("Merging results...")
    for result in results:
        for cell_id, node_data in result:
            grid_cells[cell_id].append(node_data)
    
    # Print grid statistics
    cells_with_data = sum(1 for nodes in grid_cells.values() if len(nodes) > 0)
    total_cells = len(grid_cells)
    print(f"\nGrid Statistics:")
    print(f"Total nodes assigned: {nodes_assigned}")
    print(f"Cells with data: {cells_with_data} out of {total_cells} ({cells_with_data/total_cells*100:.1f}%)")
    print("Saving results (SWA_source_to_station geometric (circular) averages)...")

    # Create inverse transformer for output
    inv_transformer = pyproj.Transformer.from_crs('EPSG:32628', 'EPSG:4326', always_xy=True)

    # Save grid cell nodes
    print("Writing grid nodes...")
    with open(grid_nodes_filename, 'w') as f:
        f.write("# lat, lon, SWA_source_to_station, tlag, weight\n")
        for cell_id, nodes in grid_cells.items():
            f.write(f"Cell {cell_id}: {len(nodes)} nodes\n")
            for x, y, swa_source_to_station, tlag, weight in nodes:
                lon, lat = inv_transformer.transform(x, y)
                f.write(f"{lat:.4f}, {lon:.4f}, {swa_source_to_station:.4f}, {tlag:.4f}, {weight:.4f}\n")
    
    # Save grid cell centers with average values and node counts
    print("Writing grid cell centers and geometric mean SWA_source_to_station plus node counts for plotting...")
    with open(grid_cells_averages_filename, 'w') as f:
        f.write("# Columns: lon, lat, SWA_source_to_station_geometric_mean, num_nodes\n")
        for i in range(len(x_coords)-1):
            for j in range(len(y_coords[0])-1):
                cell_id = f"{i}_{j}"
                cell_center_x = (x_coords[i,j] + x_coords[i+1,j]) / 2
                cell_center_y = (y_coords[i,j] + y_coords[i,j+1]) / 2
                nodes = grid_cells[cell_id]
                if len(nodes) > 0:
                    swa_source_to_station_values = np.array([node[2] for node in nodes])
                    weights = np.array([node[4] for node in nodes])
                    avg_swa_source_to_station = calculate_geometric_mean(swa_source_to_station_values, weights)
                    center_lon, center_lat = inv_transformer.transform(cell_center_x, cell_center_y)
                    num_nodes = len(nodes)
                    f.write(f"{center_lon:.4f}, {center_lat:.4f}, {avg_swa_source_to_station:.2f}, {num_nodes}\n")

    # Save GMT-compatible xyz file for grid cells
    print("Writing GMT xyz file...")
    with open(grid_xyz_filename, 'w') as f:
        for i in range(len(x_coords)-1):
            for j in range(len(y_coords[0])-1):
                corners_x = [x_coords[i,j], x_coords[i+1,j], x_coords[i+1,j+1], x_coords[i,j+1], x_coords[i,j]]
                corners_y = [y_coords[i,j], y_coords[i+1,j], y_coords[i+1,j+1], y_coords[i,j+1], y_coords[i,j]]
                
                for x, y in zip(corners_x, corners_y):
                    lon, lat = inv_transformer.transform(x, y)
                    f.write(f"{lon:.4f}\t{lat:.4f}\n")
                f.write("NaN\tNaN\n")
    
    end_time = time.time()
    print(f"Gridding complete! Total runtime: {end_time - start_time:.2f} seconds")
    print(f"Wrote files:\n  {grid_nodes_filename}\n  {grid_cells_averages_filename}\n  {grid_xyz_filename}")

if __name__ == "__main__":
    main()
