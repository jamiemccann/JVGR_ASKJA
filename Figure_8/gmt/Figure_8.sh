# --- i/o paths ---
GMTDATA=../../gmt_data
Data=../data
! [ -d plots ] && mkdir plots



# --- Input information ---
NAME=Figure_8
ratio=1:160000
ROSE_INPUT_PATH=$Data/rose_generator_rose_input.txt
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

# --- Define plot region and projection ---
region=-17.02/-16.45/64.9/65.2
proj=M25c
gmt mapproject -R$region -J$proj -W > tmp
read w h < tmp
ratio=1:160000


# --- The colour zone ---
gmt makecpt -C$GMTDATA/grey_poss.cpt -T-3500/2500/1 -Z > topo.cpt


function plotrose() {
    # Plots a rose diagram at a geographical location on a GMT map
    # Uses the command mapproject to find geographical location
    #
    # Parameters
    #   1: longitude
    #   2: latitude
    #   3: rosefile

    # Calculate x-off and y-off
    echo $1 $2 | gmt mapproject -J$proj -R$region > starose.xy
    read xoff yoff < starose.xy
    # Remove - 0.5 offset. We will use -D for positioning instead.
    xoff=$(echo "$xoff - 0.5" | bc -l); yoff=$(echo "$yoff - 0.5" | bc -l)

    # Using -D to specify map location for rose diagram, 
    # try increasing -JX... scaling (to, say, -JX2c) so that the rose plot appears larger

    awk -F "," 'FNR > 1 {print 1,$22}' $3 | gmt rose -I -T > tmprose.stats  # CHANGE $20 TO CORRECT COLUMN VAL - EXPECTS HEADER
    read N MAZ MR MRL MBS SM LLS < tmprose.stats
    rm tmprose.stats
    # clr=`awk -v mrl="$MRL" '{if ($1<=mrl && $3>mrl) {print $2}}' fast.cpt`

    # Use -D to directly place rose on plot, -JX2c to control rose size, remove -Xa/-Ya
    awk -F "," 'FNR > 1 {print $21}' $3 | gmt rose -R0/0.001/0/360 -B+w0.01 -Gred@10 -i0 -Sn0.5ca -JX1. -T -L -A15 -Xa$xoff -Ya$yoff -W0.5,red

}

gmt begin plots/$NAME png dpi 150
    
    

    
    echo "   ...plotting topography..."
    gmt grdimage $GMTDATA/IcelandDEM_20m.grd -I$GMTDATA/IcelandDEM_20mI.grd -Ctopo.cpt -R$region -J$proj -X4c -Y8c 

    

    

    

    echo "   ...plotting fractures..."
    gmt plot $GMTDATA/sNVZ_fractures.xy  -W0.25p,black

    echo "   ...plotting Askja caldera complex..."
    gmt plot $GMTDATA/askja_caldera.xy -Sf0.10/0.085c+l -W0.5p,black

    echo "plotting askja lakes"
    gmt plot $GMTDATA/askja_lakes.xy -Gblue@80


    echo "   ...plotting rose diagrams..."
    while read lon lat rosefile station; do
        plotrose $lon $lat $rosefile
        # echo "$lon $lat $station" | gmt text -F+f10p,Helvetica-Bold,black+jTC -J$proj -R$region
    done < $ROSE_INPUT_PATH


   

    
    
    

    echo "   ...adding panel borders, ticks, and compass..."
    gmt basemap -J$proj -R$region -Tdx2c/$(echo "$h-3" | bc)c+w2c+l,,,N \
        --FONT_ANNOT=16p,Helvetica


    echo " ... plotting basemap..."
    # DEBUG: Print width and height to help diagnose issues
    echo "[DEBUG] w=$w h=$h"S
    # Check if w is a valid number (not empty or NaN)
    if [[ -z "$w" || "$w" == "nan" || "$w" == "NaN" ]]; then
        echo "[ERROR] Variable 'w' is not set correctly. Skipping basemap plotting."
    else
        x_pos=$(echo "$w-0.5" | bc)
        echo "[DEBUG] Calculated x_pos=$x_pos"
        gmt basemap -Lx${x_pos}c/1c+c65+w10k+lkm+jBR \
            --FONT_ANNOT=16p,Helvetica  \
            -Bxa0.25df0.125d -Bya0.1df0.05d -BSWne
        basemap_code=$?
        if [ $basemap_code -ne 0 ]; then
            echo "[ERROR] gmt basemap failed with code $basemap_code"
        fi
    fi


# Try to safely close GMT if stuck, and always remove tmp regardless
gmt end 

echo "...removing temporary files..."
rm tmp   gmt.*

echo "Complete."