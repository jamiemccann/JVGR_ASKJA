# --- i/o paths ---
GMTDATA=/raid2/jam247/Askja_Final/gmt_data
[ ! -d plots ] && mkdir plots

gmt set PS_MEDIA 2500x2500
gmt set PS_PAGE_ORIENTATION landscape
gmt set PS_PAGE_COLOR White
gmt set FONT_TITLE 16p, Helvetica
gmt set FONT_ANNOT 12p, Helvetica
gmt set FONT_LABEL 12p, Helvetica
gmt set MAP_FRAME_TYPE plain
gmt set MAP_FRAME_PEN 1.2p
gmt set MAP_TICK_LENGTH 0.3c
gmt set MAP_TICK_PEN_PRIMARY 0.75p
# gmt set FORMAT_GEO_MAP ddd.xx

# --- Input information ---
NAME=Figure_11
ratio=1:160000

# --- Define plot region and projection ---
region=-17.02/-16.45/64.9/65.2
proj=M12c  # Use smaller panel size per subplot


SPLITTING_GRID_RESULTS=$(realpath /raid2/jam247/A_Askja_Paper/PAPER_FIGURES/Figure_9/gridding_script/FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2/FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2_grid_cells_with_averages.txt)


# --- The colour zone ---
gmt makecpt -C$GMTDATA/grey_poss.cpt -T-3500/2500/1 -Z > topo.cpt
gmt makecpt -Cpolar -T-1/1/0.2 -Z > strain_interp.cpt
gmt makecpt -Cviridis -T-0/1.0/0.001 -Z > devstress.cpt
gmt makecpt -Cmagma -T0/6/0.01   > swa.cpt
# --- Only use data files at 2km for first three panels ---
stress_vector_2km="/raid2/jam247/A_Askja_Paper/PAPER_FIGURES/Figure_11/model_results/stress_vectors_depth_2km.csv"
vol_strain_2km="/raid2/jam247/A_Askja_Paper/PAPER_FIGURES/Figure_11/model_results/volumetric_strain_values_depth_2km_interpolated.xyz"
devstress_2km="/raid2/jam247/A_Askja_Paper/PAPER_FIGURES/Figure_11/model_results/horizontal_principal_stress_diff_values_depth_2km_interpolated.xyz"

# Panel titles
panel_titles=(
    "Maximum Horizontal Stress - 2 km"
    "Volumetric Strain - 2 km"
    "Horizontal Differential Stress - 2 km"
    "Spatially-Averaged SWA and @~q@~"
)

gmt begin plots/$NAME png dpi 150

# Panel layout: 2x2 panels
gmt subplot begin 2x2 -Fs12c/10c -M0.4c/0.9c -SRl -R$region -J$proj -Baf

# Title position
title_x="-17.02"
title_y="65.22"

for panel in 0 1 2 3; do
    row=$((panel / 2))
    col=$((panel % 2))
    gmt subplot set ${row},${col}

    # Plot topography for all panels
    gmt grdimage /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/IcelandDEM_20m.grd \
        -I/raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/IcelandDEM_20mI.grd \
        -Ctopo.cpt -R$region -J$proj

    # Add faults, lakes, etc
    gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/sNVZ_fractures.xy  -W0.25p,black -R$region -J$proj
    gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/askja_caldera.xy -Sf0.10/0.085c+l -W0.5p,black -R$region -J$proj
    gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/askja_lakes.xy -Gblue@80 -R$region -J$proj
    gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/roads_updated.xy -W0.25p,black -R$region -J$proj

    # Panel content by panel number
    if [[ $panel -eq 0 ]]; then
        # Maximum horizontal stress - 2km
        awk -F',' '{print $1, $2, $3, 0.2}' "$stress_vector_2km" | \
        gmt plot -Sv0.2c -W1.5p,black
        # Legend for modelled SHmax vectors in this panel
        echo "S +0.10c - 0.55c black thickest,black 0.55c Modelled SHmax" | \
            gmt legend -R$region -J$proj -DjBR+w4.1c/0.35c+o1.0c/0.65c \
                -F+gwhite+p1p+c0.25c --FONT_ANNOT=12p,Helvetica
    elif [[ $panel -eq 1 ]]; then
        # Volumetric strain - 2km
        awk '{print $1, $2, $3*1e6}' "$vol_strain_2km" | gmt plot -Cstrain_interp.cpt -Sc0.15c -R$region -J$proj
        gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/sNVZ_fractures.xy -W0.25p,black -R$region -J$proj
        gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/askja_caldera.xy -Sf0.10/0.085c+l -W0.5p,black -R$region -J$proj
        # Add colorbar for volumetric strain inside this panel
        # Placement: bottom right, smaller bar, shifted up
        gmt colorbar -Cstrain_interp.cpt -Dx7.9c/2.5c+w3c/0.25c+h+e -Bxa1+l"Vol. Microstrain" -By -G-1/1 -F+gwhite+p1p+c0.25c/0.25c/0.9c/0.25c -R$region -J$proj --FONT_ANNOT=13p,Helvetica --FONT_LABEL=13p,Helvetica
    elif [[ $panel -eq 2 ]]; then
        # Horizontal differential stress - 2km
        gmt plot "$devstress_2km" -Cdevstress.cpt -Sc0.15c -R$region -J$proj
        gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/sNVZ_fractures.xy -W0.25p,black -R$region -J$proj
        gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/askja_caldera.xy -Sf0.10/0.085c+l -W0.5p,black -R$region -J$proj
        # Add colorbar for devstress inside this panel
        # Placement: bottom right, smaller bar, shifted up
        gmt colorbar -Cdevstress.cpt -Dx7.9c/2.5c+w3c/0.25c+h+e -Bxa0.5f0.1+l"Diff. Stress (MPa)" -By -G0/1.0 -F+gwhite+p1p+c0.25c/0.25c/0.9c/0.25c -R$region -J$proj --FONT_ANNOT=13p,Helvetica --FONT_LABEL=13p,Helvetica
    else
        # Fourth panel: leave blank, user will fill in as desired
        # Create interpolated grid of SWA values, limited to data coverage area
        # 1. Extract points where there is SWA data (column 4 > 100)
        awk -F',' '!/^#/ && $4 > 1000 {print $1, $2, $3}' /raid2/jam247/A_Askja_Paper/PAPER_FIGURES/Figure_10/FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2/FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2_grid_cells_SWA_source_to_station_averages.txt > swa_tmp.xyz

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

        awk '$5 <= 0.05 && $6 >= 1000 {
        print $1, $2, $3, 0.2;           # original azimuth
        print $1, $2, ($3+180)%360, 0.2  # opposite direction
    }' $SPLITTING_GRID_RESULTS | \
    gmt plot -Sv0.2c -W1.5p,red

        # Add colorbar for SWA inside this panel
        # Placement: bottom right, smaller bar, shifted up
        gmt colorbar -Cswa.cpt -Dx8.4c/2.5c+w3c/0.25c+h+e -Bpa1f1+l"SWA %" -By -G0/6 -F+gwhite+p1p+c0.25c/0.25c/0.9c/0.25c -R$region -J$proj --FONT_ANNOT=13p,Helvetica --FONT_LABEL=13p,Helvetica

        # Compact legend label for plotted fast polarisations below SWA scale bar
        echo "S +0.04c - 0.24c red 0.8p,red 0.24c Average @~f@~" | \
            gmt legend -R$region -J$proj -DjBR+w1.30c+o2.1c/0.26c --FONT_ANNOT=12p,Helvetica
    fi

    # Add panel title if set
    if [[ -n "${panel_titles[$panel]// }" ]]; then
        gmt pstext -R$region -J$proj -F+f18p,Helvetica-Bold,black+jTL -N <<- EOF
        $title_x $title_y ${panel_titles[$panel]}
EOF
    fi

done

gmt subplot end

# No global colorbars; all colorbars are now per-panel/subplot.

gmt end

echo "...removing temporary files..."
rm -f tmp gmt.*

echo "Complete."
