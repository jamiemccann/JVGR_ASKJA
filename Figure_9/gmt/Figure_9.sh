# --- i/o paths ---
GMTDATA=../../gmt_data
Data=../data
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
NAME=Figure_9
ratio=1:160000


# Set relative path to splitting file for plotting average results etc.
SPLITTING_GRID_XY='../gridding_script/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2_grid.xyz'
SPLITTING_GRID_RESULTS='../gridding_script/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2_grid_cells_with_averages.txt'



# --- Define plot region and projection ---
region=-17.02/-16.45/64.9/65.2
proj=M25c
gmt mapproject -R$region -J$proj -W > tmp
read w h < tmp
ratio=1:160000


# --- The colour zone ---
gmt makecpt -C$GMTDATA/grey_poss.cpt -T-3500/2500/1 -Z > topo.cpt
gmt makecpt -Cmagma -T10/30/1 -Ic > fast.cpt
gmt makecpt -Cmagma -T0/1/0.001 -Ic > fast.cpt
gmt makecpt -Cmagma -T0/10/0.1   > swa.cpt
gmt makecpt -Cmagma -T-90/90/5 > fastaxis.cpt
gmt #makecpt -Cmagma -T0/0.2/0.0 > strength.cpt
gmt makecpt -Cmagma -T-0.001/0.05/0.001 -Ic > color_palette.cpt
gmt makecpt -Cmagma -T-0.001/1.001/0.001 -Ic > color_palette_Rbar.cpt
gmt makecpt -Cjet -T-0.03/0.04/0.001 -Ic > tlag_diff.cpt
gmt makecpt -Cmagma -T0.5/1/0.01 -A25 -Ic >res_len.cpt
gmt makecpt -Cmagma -T0/100/1 > num_points.cpt



gmt begin plots/$NAME png dpi 150
    echo "   ...plotting topography..."
    gmt grdimage $GMTDATA/IcelandDEM_20m.grd -I$GMTDATA/IcelandDEM_20mI.grd -Ctopo.cpt -R$region -J$proj -X4c -Y8c 


    echo "   ...plotting fractures..."
    gmt plot $GMTDATA/sNVZ_fractures.xy  -W0.25p,black

    echo "   ...plotting Askja caldera complex..."
    gmt plot $GMTDATA/askja_caldera.xy -Sf0.10/0.085c+l -W0.5p,black

    echo "plotting askja lakes"
    gmt plot $GMTDATA/askja_lakes.xy -Gblue@80

    echo "plotting askja roads"
    gmt plot $GMTDATA/roads_updated.xy -W0.25p,black

    echo "plotting reference opposite vectors (106 deg from north)"
    
    {
        echo "-16.9 65.175 344 3.5"
        echo "-16.9 65.175 164 3.5"
    } | gmt plot -J$proj -R$region -Sv0.9c+e -W3p,darkgreen
    echo "-16.9 65.18 Plate Spreading Direction" | \
        gmt text -J$proj -R$region -F+f14p,Helvetica-Bold,darkgreen+jBC+a-16


    

   
    
     # --- Plot average results ---
    echo "Plotting average results..."

    awk '$5 <= 0.05 && $6 >= 1000 {
        print $1, $2, $3, 0.4;           # original azimuth
        print $1, $2, ($3+180)%360, 0.4  # opposite direction
    }' $SPLITTING_GRID_RESULTS | \
    gmt plot -J$proj -R$region -Sv0.2c -W3p,red


    awk '$5 > 0.05 && $6 >= 1000 {
        print $1, $2, $3, 0.4;           # original azimuth
        print $1, $2, ($3+180)%360, 0.4  # opposite direction
    }' $SPLITTING_GRID_RESULTS | \
    gmt plot -J$proj -R$region -Sv0.2c -W3p,blue


    echo "Plotting grid..."
    gmt plot -J$proj -R$region -W0.05p,black $SPLITTING_GRID_XY 




    








    echo "   ...adding panel borders, ticks, compass..."
    # Place compass in bottom left: -Td for compass rose, place at x=2c/y=2c (near bottom left)
    gmt basemap -J$proj -R$region -Td2c/2c+w2c+l,,,N --FONT_ANNOT=16p,Helvetica

    gmt basemap -Lx$(echo "$w-0.3" | bc)c/1c+c65+w10k+lkm+jBR \
         -F+p1p,black+gwhite+c0.02c/0.02c/0.12c/1.6c --FONT_ANNOT=14p,Helvetica  \
        -Bxa0.25df0.125d -Bya0.1df0.02d -BSWne

    # Center the legend in the right box in the x-direction, keep y-offset at 1.3c (same as before)
    # The right box is 1.2i wide, so offset the legend by -0.6i (half width) to center it
    echo "S +0.1c - 0.8c blue thickest,blue 0.82c Spatially-Averaged @~f@~ (p>0.05)
S +0.1c - 0.8c red thickest,red 0.82c Spatially-Averaged @~f@~ (p<=0.05)" | \
        gmt legend -J$proj -R$region -DjBR+w1.2i+o6c/1.3c --FONT_ANNOT=15p,Helvetica --FONT_LABEL=14p,Helvetica
 
   

    

gmt end 

echo "...removing temporary files..."
rm tmp gmt.* *.cpt

echo "Complete."