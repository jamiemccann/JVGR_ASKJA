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
gmt set FORMAT_GEO_MAP ddd.xx








# --- Input information ---
NAME=Figure_11
ratio=1:160000



# --- Define plot region and projection ---
region=-17.02/-16.45/64.9/65.2
proj=M12c  # Use smaller panel size per subplot

# --- The colour zone ---
gmt makecpt -C$GMTDATA/grey_poss.cpt -T-3500/2500/1 -Z > topo.cpt
gmt makecpt -Cpolar -T-3e-06/3e-06/2e-07 -Z > strain_interp.cpt
gmt makecpt -Cviridis -T-0/2.0/0.001 -Z > devstress.cpt  # Example: change range as needed!

# --- Data files for each panel (see assignment below for meaning)
stress_vector_files=(
    "/raid2/jam247/A_Askja_Paper/PAPER_FIGURES/Figure_11/model_results/stress_vectors_depth_0km.csv"
    "/raid2/jam247/A_Askja_Paper/PAPER_FIGURES/Figure_11/model_results/stress_vectors_depth_2km.csv"
)
vol_strain_files=(
    "/raid2/jam247/A_Askja_Paper/PAPER_FIGURES/Figure_11/model_results/volumetric_strain_values_depth_0km_interpolated.xyz"
    "/raid2/jam247/A_Askja_Paper/PAPER_FIGURES/Figure_11/model_results/volumetric_strain_values_depth_2km_interpolated.xyz"
)
devstress_files=(
    "/raid2/jam247/A_Askja_Paper/PAPER_FIGURES/Figure_11/model_results/horizontal_principal_stress_diff_values_depth_0km_interpolated.xyz"
    "/raid2/jam247/A_Askja_Paper/PAPER_FIGURES/Figure_11/model_results/horizontal_principal_stress_diff_values_depth_2km_interpolated.xyz"
)

# Panel titles: order matches subplot panel order below
panel_titles=(
    "Maximum Horizontal Stress - 0 km"
    "Maximum Horizontal Stress - 2 km"
    "Volumetric Strain - 0 km"
    "Volumetric Strain - 2 km"
    "Horizontal Differential Stress - 0 km"
    "Horizontal Differential Stress - 2 km"
)

gmt begin plots/$NAME png

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
    gmt grdimage /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/IcelandDEM_20m.grd \
        -I/raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/IcelandDEM_20mI.grd \
        -Ctopo.cpt -R$region -J$proj

    # Add faults, lakes, etc
    gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/sNVZ_fractures.xy  -W0.25p,black -R$region -J$proj
    gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/askja_caldera.xy -Sf0.10/0.085c+l -W0.5p,black -R$region -J$proj
    gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/askja_lakes.xy -Gblue@80 -R$region -J$proj
    gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/roads_updated.xy -W0.25p,black -R$region -J$proj

    # Panel content
    if [[ $i -eq 0 ]] || [[ $i -eq 1 ]]; then
        # Stress vectors as in Figure_9.sh (see context lines 76-80): show direction and opposite
        awk -F',' '{print $1, $2, $3, 0.2}' "${stress_vector_files[i]}" | \
        gmt plot -Sv0.2c -W1.5p,black
    elif [[ $i -eq 2 ]] || [[ $i -eq 3 ]]; then
        # Volumetric strain: plot as colored circles with strain_interp colour table
        # -t sets transparency in percent (0=opaque, 100=invisible)
        gmt plot "${vol_strain_files[$((i-2))]}" -Cstrain_interp.cpt -Sc0.15c -R$region -J$proj 
        gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/sNVZ_fractures.xy  -W0.25p,black -R$region -J$proj
    gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/askja_caldera.xy -Sf0.10/0.085c+l -W0.5p,black -R$region -J$proj
    elif [[ $i -eq 4 ]] || [[ $i -eq 5 ]]; then
        # Deviatoric stress: plot as colored circles, using devstress.cpt
        gmt plot "${devstress_files[$((i-4))]}" -Cdevstress.cpt -Sc0.15c -R$region -J$proj 
        gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/sNVZ_fractures.xy  -W0.25p,black -R$region -J$proj
    gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/askja_caldera.xy -Sf0.10/0.085c+l -W0.5p,black -R$region -J$proj
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

gmt subplot end

# Optional: Add a colorbar for each field as desired below (uncomment and edit positions/range/title)
# Place Volumetric Strain colorbar at the left, Deviatoric Stress colorbar at the right
# Move them up a bit so the bottoms are not clipped
gmt colorbar -Cstrain_interp.cpt -Dx0.5c/-1.2c+w10c/0.5c+h -Bxa1e-6f2e-7+l"Volumetric Strain" -By -G-3e-6/3e-6
gmt colorbar -Cdevstress.cpt -Dx15c/-1.2c+w10c/0.5c+h -Bxa0.5f0.1+l"Deviatoric Stress" -By -G0/2.0

gmt end

echo "...removing temporary files..."
rm -f tmp gmt.*

echo "Complete."
