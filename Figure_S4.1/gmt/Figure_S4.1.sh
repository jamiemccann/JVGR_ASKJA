#!/usr/bin/env bash
# Paths are resolved from this script's directory so the script works from any cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# --- i/o paths ---
GMTDATA="${SCRIPT_DIR}/../../gmt_data"
GRID_DATA_DIR="${SCRIPT_DIR}/../gridding_script"

[ ! -d plots ] && mkdir plots




# gmt set PS_MEDIA 2500x2500
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
NAME=Figure_S4.1
OUTPUT_PNG="plots/${NAME}.png"

ratio=1:160000

# --- Define plot region and projection ---
region=-17.12/-16.2/64.89/65.25
# proj=M25c
proj=M12c  # Use smaller panel size per subplot

# --- The colour zone ---
gmt makecpt -C$GMTDATA/grey_poss.cpt -T-3500/2500/100 -Z > topo.cpt
gmt makecpt -Cmagma -T10/30/1 -Ic > fast.cpt
gmt makecpt -Cmagma -T0/1/0.001 -Ic > fast.cpt
gmt makecpt -Cmagma -T0/10/0.1   > swa.cpt
gmt makecpt -Cmagma -T-90/90/5 > fastaxis.cpt
# gmt makecpt -Cmagma -T0/0.2/0.0 > strength.cpt
gmt makecpt -Cmagma -T-0.001/0.05/0.001 -Ic > color_palette.cpt
gmt makecpt -Cmagma -T-0.001/1.001/0.001 -Ic > color_palette_Rbar.cpt
gmt makecpt -Cjet -T-0.03/0.04/0.001 -Ic > tlag_diff.cpt
gmt makecpt -Cmagma -T0.5/1/0.01 -A25 -Ic >res_len.cpt
gmt makecpt -Cmagma -T0/100/1 > num_points.cpt
gmt makecpt -Cpolar -T-2.5/2.5/0.05 > strain.cpt

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
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_equal/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_equal_grid_cells_with_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist_grid_cells_with_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2_grid_cells_with_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_equal/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_equal_grid_cells_with_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_inv_dist/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_inv_dist_grid_cells_with_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_inv_dist2/ACl_FILTERED_DATA_04_xinc3km_yinc3km_weighting_inv_dist2_grid_cells_with_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_equal/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_equal_grid_cells_with_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_inv_dist/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_inv_dist_grid_cells_with_averages.txt"
    "$GRID_DATA_DIR/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_inv_dist2/ACl_FILTERED_DATA_04_xinc5km_yinc5km_weighting_inv_dist2_grid_cells_with_averages.txt"
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

gmt begin plots/$NAME png dpi 80

# Panel layout: 2 columns x 3 rows, shared region/proj, small spacing
# Remove -A for panel titles controlled by subplot, do not use -A here, we will handle titles manually
gmt subplot begin 3x3 -Fs12c/10c -M0.4c/0.9c -SRl -Rg -Brt -BWSne

# Title positions: Always use -17.08 for first column, -16.38 for second column
title_x_left="-17.08"
title_x_right="-16.38"
title_y="65.235"

for ((i=0; i<9; i++)); do
    gmt subplot set $i

    # Set len_bar based on panel index
    case $i in
        0|1|2)
            len_bar=0.2
            ;;
        3|4|5)
            len_bar=0.4
            ;;
        6|7|8)
            len_bar=0.6
            ;;
        *)
            len_bar=0.2
            ;;
    esac
    len_bar_float=$(printf "%.1f" "$len_bar")
    echo $len_bar_float

    # Plot topography
    gmt grdimage $GMTDATA/IcelandDEM_20m.grd \
        -Ctopo.cpt -R$region -J$proj

    
    gmt plot $GMTDATA/askja_caldera.xy -Sf0.10/0.085c+l -W0.5p,black
    
    # Plot grid outline
    gmt plot "${grid_files[i]}" -W0.05p,black

    # Plot the stress vectors for this panel
    awk -v len_bar="$len_bar_float" '$5 <= 0.05 && $6 >= 1000 {
        print $1, $2, $3, len_bar;           # original azimuth
        print $1, $2, ($3+180)%360, len_bar  # opposite direction
    }' "${average_files[i]}" | \
    gmt plot -Sv0.2c -W3p,red





    
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


gmt end

if [ -f "$OUTPUT_PNG" ]; then
    before_bytes=$(stat -c%s "$OUTPUT_PNG")

    if command -v pngquant >/dev/null 2>&1; then
        pngquant --force --skip-if-larger --quality=55-85 --speed 1 \
            --output "$OUTPUT_PNG" -- "$OUTPUT_PNG"
    fi

    if command -v optipng >/dev/null 2>&1; then
        optipng -quiet -o7 "$OUTPUT_PNG" >/dev/null 2>&1 || true
    fi

    after_bytes=$(stat -c%s "$OUTPUT_PNG")
    echo "PNG size: ${before_bytes} -> ${after_bytes} bytes"
fi

echo "...removing temporary files..."
rm -f tmp gmt.* *.cpt

echo "Complete."
