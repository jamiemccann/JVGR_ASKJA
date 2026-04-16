#!/usr/bin/env bash
# Resolve paths from this script's directory so the script works from any cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# --- i/o paths ---
# Default to JVGR_PAPER shared GMT assets; override if needed, e.g. export GMTDATA=/path/to/gmt_data
GMTDATA="${GMTDATA:-${SCRIPT_DIR}/../../gmt_data}"
MODEL_RESULTS_DIR="${SCRIPT_DIR}/../../Figure_11/model_results"

[ ! -d plots ] && mkdir plots



gmt set PS_MEDIA 2500x2500
gmt set PS_PAGE_ORIENTATION landscape
gmt set PS_PAGE_COLOR White
gmt set FONT_TITLE 16p,Helvetica
gmt set FONT_ANNOT 12p,Helvetica
gmt set FONT_LABEL 12p,Helvetica
gmt set MAP_FRAME_TYPE plain
# gmt set MAP_FRAME_PEN 1.2p
# gmt set MAP_TICK_LENGTH 0.3c
# gmt set MAP_TICK_PEN_PRIMARY 0.75p
# gmt set FORMAT_GEO_MAP ddd.xx








# --- Input information ---
NAME=Figure_S6.2
ratio=1:160000



# --- Define plot region and projection ---
region=-17.02/-16.45/64.9/65.2
proj=M12c  # Use smaller panel size per subplot

# --- The colour zone ---
gmt makecpt -C$GMTDATA/grey_poss.cpt -T-3500/2500/1 -Z > topo.cpt
gmt makecpt -Cpolar -T-3/3/0.2 -Z > strain_interp.cpt
gmt makecpt -Cviridis -T-0/2.0/0.001 -Z > devstress.cpt  # Example: change range as needed!

# --- Data files for each panel (see assignment below for meaning)


stress_vector_files=(
    "$MODEL_RESULTS_DIR/volumetric_strain_values_depth_0km_interpolated.xyz"
    "$MODEL_RESULTS_DIR/volumetric_strain_values_depth_1km_interpolated.xyz"
    "$MODEL_RESULTS_DIR/volumetric_strain_values_depth_2km_interpolated.xyz"
    "$MODEL_RESULTS_DIR/volumetric_strain_values_depth_3km_interpolated.xyz"
    "$MODEL_RESULTS_DIR/volumetric_strain_values_depth_4km_interpolated.xyz"
    "$MODEL_RESULTS_DIR/volumetric_strain_values_depth_5km_interpolated.xyz"
)

# Panel titles: order matches subplot panel order below
panel_titles=(
    "Volumetric Strain - 0 km"
    "Volumetric Strain - 1 km"
    "Volumetric Strain - 2 km"
    "Volumetric Strain - 3 km"
    "Volumetric Strain - 4 km"
    "Volumetric Strain - 5 km"
)

gmt begin plots/$NAME png dpi 150

# Panel layout: 2 columns x 3 rows, shared region/proj, small spacing
# Make borders plain: just use -Baf without -BWSne/fancy annotations
gmt subplot begin 3x2 -Fs12c/10c -M0.4c/0.9c -SRl -R$region -J$proj -Baf

# Title positions
title_x_left="-17.02"
title_x_right="-16.38"
title_y="65.22"

for ((i=0; i<6; i++)); do
    row=$((i / 2))
    col=$((i % 2))
    gmt subplot set ${row},${col}

    # Plot topography for all panels
    gmt grdimage "$GMTDATA/IcelandDEM_20m.grd" \
        -I"$GMTDATA/IcelandDEM_20mI.grd" \
        -Ctopo.cpt -R$region -J$proj

    # Add faults, lakes, etc
    gmt plot "$GMTDATA/sNVZ_fractures.xy" -W0.25p,black -R$region -J$proj
    gmt plot "$GMTDATA/askja_caldera.xy" -Sf0.10/0.085c+l -W0.5p,black -R$region -J$proj
    gmt plot "$GMTDATA/askja_lakes.xy" -Gblue@80 -R$region -J$proj
    
    # Panel content
    if (( i < 6 )); then
        # Stress vectors as in Figure_9.sh (see context lines 76-80): show direction and opposite
        gmt plot "${stress_vector_files[i]}" -i0,1,2+s1e6 -Cstrain_interp.cpt -Sc0.15c -R$region -J$proj
        gmt plot "$GMTDATA/sNVZ_fractures.xy" -W0.25p,black -R$region -J$proj
        gmt plot "$GMTDATA/askja_caldera.xy" -Sf0.10/0.085c+l -W0.5p,black -R$region -J$proj
    fi

    

    # Titles (left column vs right column)
    if (( col == 0 )); then
        title_x="$title_x_left"
    else
        title_x="$title_x_left"
    fi

    gmt pstext -R$region -J$proj -F+f18p,Helvetica-Bold,black+jTL -N <<- EOF
    $title_x $title_y ${panel_titles[$i]}
EOF
done
gmt colorbar -Cstrain_interp.cpt -Dx8.4c/2.4c+w3c/0.25c+h+e -Bxa1f0.5+l"Microstrain" -By -G-3/3 -F+gwhite+p1p+c0.25c -R$region -J$proj --FONT_ANNOT=18p,Helvetica --FONT_LABEL=24p,Helvetica
gmt subplot end

# Optional: Add a colorbar for each field as desired below (uncomment and edit positions/range/title)
# Place Volumetric Strain colorbar at the left, Deviatoric Stress colorbar at the right
# Move them up a bit so the bottoms are not clipped

gmt end

echo "...removing temporary files..."
rm -f tmp gmt.* *.cpt

echo "Complete."
