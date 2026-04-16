#!/usr/bin/env bash
# Paths are resolved from this script's directory so the script works from any cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# --- i/o paths ---
GMTDATA="${SCRIPT_DIR}/../../gmt_data"
GRID_DATA_DIR="${SCRIPT_DIR}/../gridding_script"

! [ -d plots ] && mkdir plots


gmt set PS_MEDIA 2500x2500
gmt set PS_PAGE_ORIENTATION landscape
gmt set PS_PAGE_COLOR White
gmt set FONT_TITLE 16p, Helvetica
gmt set FONT_ANNOT 12p, Helvetica
gmt set FONT_LABEL 12p, Helvetica
gmt set MAP_FRAME_TYPE plain
# gmt set MAP_FRAME_PEN 1.2p
# gmt set MAP_TICK_LENGTH 0.3c
# gmt set MAP_TICK_PEN_PRIMARY 0.75p
# gmt set FORMAT_GEO_MAP ddd.xx








# --- Input information ---
NAME=Figure_S7.1
ratio=1:160000

# --- Define plot region and projection ---
region=-17.12/-16.2/64.89/65.25
proj=M12c  # Use smaller panel size per subplot

# --- The colour zone ---
gmt makecpt -C$GMTDATA/grey_poss.cpt -T-3500/2500/1 -Z > topo.cpt
gmt makecpt -Cmagma -T0/0.3/0.001   > swa.cpt

# Array of input CSVs (edit these for your actual files, in order top-left to bottom-right)
grid_files=(
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_equal/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_equal_grid.xyz"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist_grid.xyz"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2_grid.xyz"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_equal/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_equal_grid.xyz"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_inv_dist/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_inv_dist_grid.xyz"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_inv_dist2/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_inv_dist2_grid.xyz"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_equal/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_equal_grid.xyz"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_inv_dist/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_inv_dist_grid.xyz"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_inv_dist2/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_inv_dist2_grid.xyz"
) 


average_files=(
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_equal/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_equal_grid_cells_tlag_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist_grid_cells_tlag_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2_grid_cells_tlag_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_equal/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_equal_grid_cells_tlag_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_inv_dist/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_inv_dist_grid_cells_tlag_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_inv_dist2/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_inv_dist2_grid_cells_tlag_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_equal/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_equal_grid_cells_tlag_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_inv_dist/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_inv_dist_grid_cells_tlag_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_inv_dist2/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_inv_dist2_grid_cells_tlag_averages.txt"
)
# Panel titles or labels
panel_titles=(
    "2km Grid Squares, Equal Weighting"
    "2km Grid Squares, 1/d Weighting"
    "2km Grid Squares, 1/d^2 Weighting"
    "3km Grid Squares, Equal Weighting"
    "3km Grid Squares, 1/d Weighting"
    "3km Grid Squares, 1/d^2 Weighting"
    "5km Grid Squares, Equal Weighting"
    "5km Grid Squares, 1/d Weighting"
    "5km Grid Squares, 1/d^2 Weighting"
    
)

gmt begin plots/$NAME png dpi 150

# Panel layout: 2 columns x 3 rows, shared region/proj, small spacing
# Remove -A for panel titles controlled by subplot, do not use -A here, we will handle titles manually
gmt subplot begin 3x3 -Fs12c/10c -M0.4c/0.9c -SRl -Rg -Brt -BWSne

# Title positions: Always use -17.08 for first column, -16.38 for second column
title_x_left="-17.08"
title_x_right="-16.38"
title_y="65.235"

for ((i=0; i<9; i++)); do
    gmt subplot set $i

    

    # Plot topography
    gmt grdimage /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/IcelandDEM_20m.grd \
        -Ctopo.cpt -R$region -J$proj

    # # Add labels etc.
    # echo "-16.8 65.05 Askja" | gmt pstext -F+f11p,Helvetica-Bold,black
    # echo "-16.347 65.197 Herðubreið" | gmt pstext -F+f11p,Helvetica-Bold,black

    # Plot faults, lakes, etc
    # gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/sNVZ_fractures.xy  -W0.25p,black
    gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/askja_caldera.xy -Sf0.10/0.085c+l -W0.5p,black
    # gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/askja_lakes.xy -Gblue@80
    # gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/roads_updated.xy -W0.25p,black

    # Plot grid outline
    # gmt plot "${grid_files[i]}" -W0.05p,black

    # Create interpolated grid of SWA values, limited to data coverage area
    # 1. Extract points where there is SWA data (column 4 > 100)
    awk -F',' '!/^#/ && $4 > 1000 {print $1, $2, $3}' "${average_files[i]}" > swa_tmp.xyz

    # 2. Create a convex hull polygon around data points to define coverage area
    # Extract lon/lat pairs and create convex hull using Python (with fallback)
    awk '{print $1, $2}' swa_tmp.xyz | python3 -c "
import sys

# Read points first (before any try/except)
points = []
for line in sys.stdin:
    if line.strip():
        lon, lat = map(float, line.split())
        points.append([lon, lat])

try:
    from scipy.spatial import ConvexHull
    import numpy as np
    
    if len(points) > 2:
        points_array = np.array(points)
        hull = ConvexHull(points_array)
        # Output hull vertices in order (closed polygon)
        for idx in hull.vertices:
            print(f'{points_array[idx,0]} {points_array[idx,1]}')
        # Close the polygon
        print(f'{points_array[hull.vertices[0],0]} {points_array[hull.vertices[0],1]}')
    else:
        # If too few points, just output them
        for p in points:
            print(f'{p[0]} {p[1]}')
except ImportError:
    # Fallback: create bounding box with small expansion
    if points:
        lons = [p[0] for p in points]
        lats = [p[1] for p in points]
        margin = 0.01  # ~1km expansion
        print(f'{min(lons)-margin} {min(lats)-margin}')
        print(f'{max(lons)+margin} {min(lats)-margin}')
        print(f'{max(lons)+margin} {max(lats)+margin}')
        print(f'{min(lons)-margin} {max(lats)+margin}')
        print(f'{min(lons)-margin} {min(lats)-margin}')
" > swa_hull.xy

    # 3. Create a mask grid: 1 inside the convex hull (data coverage area), NaN outside
    gmt grdmask swa_hull.xy -R$region -I0.005 -Gswa_mask.grd -NNaN/1/1

    # 4. Interpolate the SWA values to a grid
    gmt surface swa_tmp.xyz -R$region -I0.005 -Gswa_tmp.grd

    # 5. Multiply the interpolated grid by the mask so interpolation only exists within data coverage
    gmt grdmath swa_tmp.grd swa_mask.grd MUL = swa_masked.grd

    # 6. Plot the masked grid image (interpolation only within data coverage area)
    # -Q makes NaN values transparent instead of gray
    # -t50 sets 50% transparency for the grid
    gmt grdimage swa_masked.grd -J$proj -R$region -Cswa.cpt -Q -t20

    # Optionally, overlay the original data as points
    # gmt plot swa_tmp.xyz -J$proj -R$region -Ss1c -W0.25p,black -Cswa.cpt -t80

    





    # Optionally, plot opposite vectors for each arrow (optional, uncomment if desired)
    # awk -F',' '{print $1, $2, ($3+180)%360, 0.4}' "${stress_vector_files[i]}" | \
    #     gmt plot -Sv0.2c+e -W3p,black
    # Always place left column titles at -17.08, right column at -16.38
    if (( (i % 2) == 0 )); then
        title_x="$title_x_left"
    else
        title_x="$title_x_left"
    fi

    gmt pstext -R$region -J$proj -F+f16p,Helvetica-Bold,black+jTL -N <<- EOF
    $title_x $title_y ${panel_titles[$i]}
EOF
done

gmt subplot end



gmt colorbar -Cswa.cpt -Dx9c/-1.3c+w20c/0.5c+h -Bpa0.1f0.1g0.4+l"Delay Time (s)" -By -G0/0.3

# Optional: Add a common legend
# echo "S +0.1c - 0.4c red thickest,black 1c Modelled Shmax" | gmt legend -DjBR+w1.2i+o0.5c/2c

gmt end

echo "...removing temporary files..."
rm -f tmp gmt.* *.cpt

echo "Complete."
