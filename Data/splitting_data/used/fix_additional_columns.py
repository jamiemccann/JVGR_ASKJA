import pandas as pd
import numpy as np
import os
from functools import lru_cache
from obspy.taup import TauPyModel
from obspy.geodetics import locations2degrees
from multiprocessing import Pool, cpu_count

"""
This script calculates source-to-station ray-path metrics for each event/station pair.
It computes path length, travel time, average velocity, SWA, and maximum traced depth.
It saves the results as additional columns in a CSV.
"""

# Get the directory where this script is located
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# =========================
# Runtime input/output config
# =========================
# Input CSV (resolved relative to this script folder)
INPUT_CSV = '/raid2/jam247/JVGR_PAPER/Data/splitting_data/used/ACl_unfiltered.csv'
# TauP velocity model
MODEL_PATH = '/raid2/jam247/A_Askja_Paper/Data/vmod/askja_vmodel_iaspei_TomVmod_paste_2shift.npz'
# Number of parallel workers
N_PROCESSES = 25
# Output CSV suffix, appended to input basename
OUTPUT_SUFFIX = '_with_additional_columns.csv'
# Optional sampling: set to an integer (e.g. 500) to run on a subset; set to None for full data
SAMPLE_SIZE = None
# Reproducible sampling seed (used only when SAMPLE_SIZE is not None)
SAMPLE_RANDOM_STATE = 42

data = pd.read_csv(INPUT_CSV)
data = data.reset_index(drop=True)
if SAMPLE_SIZE is not None:
    sample_n = min(int(SAMPLE_SIZE), len(data))
    data = data.sample(n=sample_n, random_state=SAMPLE_RANDOM_STATE).reset_index(drop=True)

# Global TauP model cached per worker process
_TAUP_MODEL = None


@lru_cache(maxsize=4)
def _cached_taup_model(model_path):
    return TauPyModel(model_path)


def _get_taup_model(model):
    if isinstance(model, TauPyModel):
        return model
    return _cached_taup_model(model)


def _init_worker_model(model_path):
    # Cache the TauP model once per worker process
    global _TAUP_MODEL
    _TAUP_MODEL = _get_taup_model(model_path)


def calculate_path_length(event, model):
    """
    Calculates the incident angle of the ray for a given event using the TauP
    toolkit wrapper provided by ObsPy. This is done using geographic
    coordinates, rather than epicentral distance angles, with the local
    velocity structure loaded into a TauP model.
    
    
    In this script, the script cannot handle velociyies above an elevation of 0, i.e. it 
    cannot deal with waves moving above the surface 

    Parameters
    ----------
    event : pandas.Series object
        Contains event and station information.
    model : obspy.taup.tau.TauPModel object
        Velocity structure to be used.

    Returns
    -------
    incident_angle : float
        Angle-of-incidence of the ray with the surface.
    takeoff_angle : float
        Direction ray shoots from source, measured in degrees from vertical.
    path : list of lists
        Path taken by the ray between source and receiver.
        Columns: [rayparam, time, distance (radians), depth, lat, lon]
    arrival : obspy.taup.tau.Arrival object
        Full arrival object for the given event.

    """
    
    
    
    #We now use the actual receiver depth
    
    #I think the 2km is that we have shifted the whole velocity model 2km, but
    #this needs to be checked
    vmod = _get_taup_model(model)
    

    anginc_epi = np.nan
    takeoff_ang_epi = np.nan

    try:
        # Safely get required keys with defaults
        depthkm = event.get('depthkm', np.nan)
        evla = event.get('evla', np.nan)
        evlo = event.get('evlo', np.nan)
        slat = event.get('slat', np.nan)
        slon = event.get('slon', np.nan)
        elev = event.get('elev', 0.0)
        
        # Check if required values are available
        if pd.isna(depthkm) or pd.isna(evla) or pd.isna(evlo) or pd.isna(slat) or pd.isna(slon):
            return 'check', 'check2', np.nan, np.nan
        
        # Use get_ray_paths which supports receiver depth
        arrival = vmod.get_ray_paths(source_depth_in_km = depthkm + 2,
                                    distance_in_degree= locations2degrees(evla, evlo, slat, slon),
                                    phase_list = ['S'],
                                    receiver_depth_in_km = -elev + 2)
                                                                        

        try:
            arrival[0]
            
        except IndexError:
            print("Cannot calculate S arrival for this event, trying s...")
            arrival = vmod.get_ray_paths(source_depth_in_km = depthkm + 2,
                                    distance_in_degree= locations2degrees(evla, evlo, slat, slon),
                                    phase_list = ['s'],
                                    receiver_depth_in_km = -elev + 2,)

        path = arrival[0].path
        traveltime = arrival[0].time
        anginc_epi = arrival[0].incident_angle
        takeoff_ang_epi = arrival[0].takeoff_angle
        
        # Calculate lat/lon along the path using great circle calculations
        # The path has 'dist' column which is distance in radians from source
        try:
            if hasattr(path, 'dtype') and path.dtype.names and 'dist' in path.dtype.names:
                distances_rad = path['dist']
                lats, lons = calculate_latlon_along_path(evla, evlo, slat, slon, distances_rad)
                
                # Add lat/lon to the path structure
                # Create a new structured array with lat/lon added
                dtype_list = list(path.dtype.descr)
                if ('lat', 'f8') not in dtype_list:
                    dtype_list.append(('lat', 'f8'))
                if ('lon', 'f8') not in dtype_list:
                    dtype_list.append(('lon', 'f8'))
                
                # Create new array with lat/lon
                new_path = np.empty(len(path), dtype=dtype_list)
                for name in path.dtype.names:
                    new_path[name] = path[name]
                new_path['lat'] = lats
                new_path['lon'] = lons
                path = new_path
        except Exception as e:
            # If lat/lon calculation fails, path will still work but without lat/lon
            # This will be handled in process_single_row
            pass
    except (IndexError, KeyError, TypeError, ValueError) as e:
        path = 'check'
        traveltime = 'check2'
        

    return path, traveltime, anginc_epi, takeoff_ang_epi


def compute_SWA(path_length, avg_velocity, delay_time):
    """
    Compute the Shear Wave Anisotropy (SWA) in percent, following Thomas & Kendall (2002).
    
    Parameters:
    -----------
    path_length : float
        The ray‐path length through the anisotropic layer in meters.
    avg_velocity : float
        The average shear‐wave velocity along the path in m/s.
    delay_time : float
        The splitting (delay) time between fast and slow shear‐wave components (s).
    
    Returns:
    --------
    SWA : float
        The estimated fractional anisotropy in percent.
    """
    # dimensionless ratio:
    
    def a1(dt, vbar, d):
        val = 2*d / (dt*vbar)

        a1 = -1*val + np.sqrt(4 + (val)**2)
        return a1 * 100
    
    
    swa = a1(delay_time, avg_velocity, path_length)
    
    return swa


def calculate_latlon_along_path(start_lat, start_lon, end_lat, end_lon, distances_rad):
    """
    Calculate latitude and longitude along a great circle path.
    
    Parameters:
    -----------
    start_lat, start_lon : float
        Starting point (event) coordinates in degrees
    end_lat, end_lon : float
        Ending point (station) coordinates in degrees
    distances_rad : array
        Distances along the path in radians (from start)
    
    Returns:
    --------
    lats, lons : arrays
        Latitude and longitude arrays along the path
    """
    # Convert to radians
    start_lat_rad = np.deg2rad(start_lat)
    start_lon_rad = np.deg2rad(start_lon)
    end_lat_rad = np.deg2rad(end_lat)
    end_lon_rad = np.deg2rad(end_lon)
    
    # Calculate initial bearing (azimuth) from start to end
    dlon = end_lon_rad - start_lon_rad
    y = np.sin(dlon) * np.cos(end_lat_rad)
    x = np.cos(start_lat_rad) * np.sin(end_lat_rad) - \
        np.sin(start_lat_rad) * np.cos(end_lat_rad) * np.cos(dlon)
    initial_bearing = np.arctan2(y, x)
    
    # Calculate angular distance from start to end
    angular_dist = np.arccos(
        np.sin(start_lat_rad) * np.sin(end_lat_rad) +
        np.cos(start_lat_rad) * np.cos(end_lat_rad) * np.cos(dlon)
    )
    
    # For each distance along the path, calculate lat/lon
    lats = []
    lons = []
    
    for dist_rad in distances_rad:
        # Calculate latitude
        lat_rad = np.arcsin(
            np.sin(start_lat_rad) * np.cos(dist_rad) +
            np.cos(start_lat_rad) * np.sin(dist_rad) * np.cos(initial_bearing)
        )
        
        # Calculate longitude
        lon_rad = start_lon_rad + np.arctan2(
            np.sin(initial_bearing) * np.sin(dist_rad) * np.cos(start_lat_rad),
            np.cos(dist_rad) - np.sin(start_lat_rad) * np.sin(lat_rad)
        )
        
        lats.append(np.rad2deg(lat_rad))
        lons.append(np.rad2deg(lon_rad))
    
    return np.array(lats), np.array(lons)


def latlon_to_xyz(lat, lon, depth_km):
    """
    Convert geographic coordinates (lat, lon, depth) to Cartesian coordinates (x, y, z).
    
    Parameters:
    -----------
    lat : float
        Latitude in degrees
    lon : float
        Longitude in degrees
    depth_km : float
        Depth in km (positive downward)
    
    Returns:
    --------
    x, y, z : float
        Cartesian coordinates in km. Origin is at Earth's center.
        x: positive eastward
        y: positive northward  
        z: positive upward (so depth makes z negative)
    """
    # Handle NaN values
    if pd.isna(lat) or pd.isna(lon) or pd.isna(depth_km):
        return np.nan, np.nan, np.nan
    
    R_EARTH = 6371.0  # Earth radius in km
    r = R_EARTH - depth_km  # radius from Earth's center
    
    # Convert to radians
    lat_rad = np.deg2rad(lat)
    lon_rad = np.deg2rad(lon)
    
    # Convert to Cartesian coordinates
    # x: east, y: north, z: up
    x = r * np.cos(lat_rad) * np.cos(lon_rad)
    y = r * np.cos(lat_rad) * np.sin(lon_rad)
    z = r * np.sin(lat_rad)
    
    return x, y, z


def calculate_path_from_source(path_df):
    """
    Calculate path length and travel time from source to station.
    
    Parameters:
    -----------
    path_df : pd.DataFrame
        DataFrame containing ray path with columns: 'depth', 'lat', 'lon', 'dist', 'time'
    Returns:
    --------
    path_length_km : float
        Path length from source to station (km)
    traveltime_s : float
        Travel time from pierce point to station (s)
    """
    path_segment = path_df.copy()
    
    if len(path_segment) < 2:
        return np.nan, np.nan

    required_cols = {'depth', 'dist', 'time'}
    if not required_cols.issubset(path_segment.columns):
        return np.nan, np.nan
    
    R_EARTH = 6371.0
    
    depth = path_segment['depth'].values
    delta = path_segment['dist'].values  # radians along the surface
    times = path_segment['time'].values
    
    # Convert to radius
    r = R_EARTH - depth
    
    # Compute segment lengths using spherical geometry
    dr = np.diff(r)
    ddelta = np.diff(delta)
    dt = np.diff(times)
    
    # Arc length for each segment
    segment_lengths = np.sqrt(dr**2 + (r[:-1] * ddelta)**2)
    
    # Total path length in km
    path_length_km = np.sum(segment_lengths)
    
    # Total travel time in seconds
    traveltime_s = np.sum(dt)
    
    return path_length_km, traveltime_s


def calculate_max_ray_depth_km(path_df):
    """
    Calculate maximum ray-traced depth in real Earth coordinates.
    
    Parameters:
    -----------
    path_df : pd.DataFrame
        DataFrame containing ray path with 'depth' in model coordinates (+2 km shift)
    
    Returns:
    --------
    max_depth_km : float
        Maximum depth in real Earth coordinates (km)
    """
    if 'depth' not in path_df.columns or path_df.empty:
        return np.nan
    max_depth_model = np.nanmax(path_df['depth'].values)
    return max_depth_model - 2.0


def process_single_row(args):
    """
    Worker function to process a single row. This is called by multiprocessing.
    
    Parameters:
    -----------
    args : tuple
        (row_dict, idx, total)
    
    Returns:
    --------
    dict : Result dictionary with source-to-station data
    """
    row_dict, idx, total = args
    model_path = _TAUP_MODEL
    
    # Get event ID first for error handling
    event_id = row_dict.get('1event', f'unknown_{idx}')
    
    try:
        # Convert None back to NaN for pandas compatibility
        clean_dict = {}
        for key, value in row_dict.items():
            if value is None:
                clean_dict[key] = np.nan
            else:
                clean_dict[key] = value
        
        # Create Series from dictionary
        row = pd.Series(clean_dict)
        
        # Calculate full ray path
        path, traveltime, anginc_epi, takeoff_ang_epi = calculate_path_length(row, model_path)
        
        if isinstance(path, str) and path == 'check':
            # Failed to calculate path
            return {
                'anginc_epi': np.nan,
                'takeoff_ang_epi': np.nan,
                'path_length_source_to_station_km': np.nan,
                'traveltime_source_to_station_s': np.nan,
                'v_avg_source_to_station_kms': np.nan,
                'SWA_source_to_station': np.nan,
                'max_ray_depth_km': np.nan,
                '1event': event_id,
                'idx': idx
            }
        
        # Convert path to DataFrame
        # The path is a numpy structured array with named fields
        # We've added lat/lon to it in calculate_path_length
        if hasattr(path, 'dtype') and path.dtype.names:
            # Structured array - convert to dict first
            df = pd.DataFrame({name: path[name] for name in path.dtype.names})
        else:
            # Try direct conversion
            df = pd.DataFrame(path)
        
        # Verify that lat/lon columns exist
        if 'lat' not in df.columns or 'lon' not in df.columns:
            print(f"Warning: Path for event {event_id} does not contain lat/lon columns. Available columns: {df.columns.tolist()}")
            # Fallback: calculate lat/lon if dist column exists
            if 'dist' in df.columns:
                distances_rad = df['dist'].values
                evla = row.get('evla', np.nan)
                evlo = row.get('evlo', np.nan)
                slat = row.get('slat', np.nan)
                slon = row.get('slon', np.nan)
                if pd.notna(evla) and pd.notna(evlo) and pd.notna(slat) and pd.notna(slon):
                    lats, lons = calculate_latlon_along_path(evla, evlo, slat, slon, distances_rad)
                    df['lat'] = lats
                    df['lon'] = lons
                else:
                    # Can't calculate, return NaN
                    return {
                        'anginc_epi': np.nan,
                        'takeoff_ang_epi': np.nan,
                        'path_length_source_to_station_km': np.nan,
                        'traveltime_source_to_station_s': np.nan,
                        'v_avg_source_to_station_kms': np.nan,
                        'SWA_source_to_station': np.nan,
                        'max_ray_depth_km': np.nan,
                        '1event': event_id,
                        'idx': idx
                    }
            else:
                # No dist column either, can't proceed
                return {
                    'anginc_epi': np.nan,
                    'takeoff_ang_epi': np.nan,
                    'path_length_source_to_station_km': np.nan,
                    'traveltime_source_to_station_s': np.nan,
                    'v_avg_source_to_station_kms': np.nan,
                    'SWA_source_to_station': np.nan,
                    'max_ray_depth_km': np.nan,
                    '1event': event_id,
                    'idx': idx
                }
        
        # Calculate full path length and travel time (source to station)
        full_path_length_km, full_traveltime_s = calculate_path_from_source(df)

        if full_traveltime_s > 0 and pd.notna(full_traveltime_s):
            v_avg_full_kms = full_path_length_km / full_traveltime_s
        else:
            v_avg_full_kms = np.nan
        
        # Recalculate SWA if tlag is available
        tlag = row.get('tlag', np.nan)

        # SWA for the full path (source to station)
        if pd.notna(tlag) and pd.notna(full_path_length_km) and pd.notna(v_avg_full_kms):
            full_path_length_m = full_path_length_km * 1000
            v_avg_full_ms = v_avg_full_kms * 1000
            swa_full = compute_SWA(full_path_length_m, v_avg_full_ms, tlag)
        else:
            swa_full = np.nan

        # Maximum ray-traced depth (real Earth coordinates)
        max_ray_depth_km = calculate_max_ray_depth_km(df)
        
        return {
            'anginc_epi': anginc_epi,
            'takeoff_ang_epi': takeoff_ang_epi,
            'path_length_source_to_station_km': full_path_length_km,
            'traveltime_source_to_station_s': full_traveltime_s,
            'v_avg_source_to_station_kms': v_avg_full_kms,
            'SWA_source_to_station': swa_full,
            'max_ray_depth_km': max_ray_depth_km,
            '1event': event_id,
            'idx': idx
        }
        
    except Exception as e:
        import traceback
        print(f"Error processing row {idx} (event: {event_id}): {str(e)}")
        print(traceback.format_exc())
        return {
            'anginc_epi': np.nan,
            'takeoff_ang_epi': np.nan,
            'path_length_source_to_station_km': np.nan,
            'traveltime_source_to_station_s': np.nan,
            'v_avg_source_to_station_kms': np.nan,
            'SWA_source_to_station': np.nan,
            'max_ray_depth_km': np.nan,
            '1event': event_id,
            'idx': idx
        }


def append_source_to_station_calculations(data, model, n_processes=10):
    """
    Calculate source-to-station ray-path metrics and recalculate SWA.
    Uses multiprocessing for parallel computation.
    
    Parameters:
    -----------
    data : pd.DataFrame
        Event dataframe, must contain columns: 'depthkm', 'evla', 'evlo', 'slat', 'slon', 'elev', 'tlag', '1event'
    model : str or TauPyModel
        Velocity structure to be used
    n_processes : int
        Number of parallel processes to use (default: 10)
    
    Returns:
    --------
    pd.DataFrame
        Original dataframe merged with source-to-station path metrics and recalculated SWA
    """
    # Limit processes to available CPU count
    max_processes = cpu_count()
    n_processes = min(n_processes, max_processes)
    
    length = len(data)
    print(f"Processing {length} events using {n_processes} processes (max available: {max_processes})...")
    
    # Prepare arguments for each row (avoid iterrows overhead)
    records = data.to_dict(orient='records')
    args_list = []
    for idx, row_dict in enumerate(records):
        # Convert numpy types to Python native types for multiprocessing
        clean_dict = {}
        for key, value in row_dict.items():
            if pd.isna(value):
                clean_dict[key] = None
            elif isinstance(value, (np.integer, np.floating)):
                clean_dict[key] = value.item()
            elif isinstance(value, (np.ndarray, pd.Series)):
                clean_dict[key] = value.tolist() if hasattr(value, 'tolist') else str(value)
            else:
                clean_dict[key] = value
        args_list.append((clean_dict, idx, length))
    
    # Process in parallel with progress tracking
    print(f"Starting parallel processing of {length} events...")
    results = []
    completed = 0
    
    # Use a pool initializer to cache the TauP model per worker
    with Pool(
        processes=n_processes,
        initializer=_init_worker_model,
        initargs=(model,)
    ) as pool:
        # Use imap_unordered for progress tracking (faster than map)
        chunksize = max(1, length // max(1, n_processes * 4))
        for result in pool.imap_unordered(process_single_row, args_list, chunksize=chunksize):
            results.append(result)
            completed += 1
            percent = (completed / length) * 100 if length > 0 else 100.0
            print(f"Progress: {completed}/{length} ({percent:.1f}%) completed")
    
    # Sort results by original index to maintain order
    results = sorted(results, key=lambda x: x['idx'])
    
    if not results:
        print("No rows to process; returning input data unchanged.")
        return data.reset_index(drop=True)

    # Convert results to DataFrame and sort by original index
    result_df = pd.DataFrame(results)
    result_df = result_df.sort_values('idx').drop('idx', axis=1)
    
    # Print summary
    successful = result_df['path_length_source_to_station_km'].notna().sum()
    print(f"Completed: {successful}/{length} successful calculations")
    
    # Align results to input row order to avoid duplication on non-unique keys
    result_df = result_df.drop(columns=['1event'], errors='ignore')
    return pd.concat(
        [data.reset_index(drop=True), result_df.reset_index(drop=True)],
        axis=1
    )




# Main execution
if __name__ == '__main__':
    # Calculate source-to-station metrics and recalculate SWA
    print(f"Calculating source-to-station metrics using {N_PROCESSES} processes...")
    new_data = append_source_to_station_calculations(data, MODEL_PATH, n_processes=N_PROCESSES)
    
    # Drop 'Unnamed: 0' column if it exists
    if 'Unnamed: 0' in new_data.columns:
        new_data.drop(columns=['Unnamed: 0'], inplace=True)
    
    # Export with input file basename
    input_base = os.path.splitext(os.path.basename(INPUT_CSV))[0]
    output_filename = f'{input_base}{OUTPUT_SUFFIX}'
    output_path = os.path.join(SCRIPT_DIR, output_filename)
    new_data.to_csv(output_path, index=False)
    
    print(f"\nResults saved to: {output_path}")
    print(f"Total events processed: {len(new_data)}")
    print(f"Successful source-to-station calculations: {new_data['path_length_source_to_station_km'].notna().sum()}")



