# --- i/o paths ---
GMTDATA=../../gmt_data
Data=../../Data
! [ -d plots ] && mkdir plots

##### NEW GRID STUFF ####

# --- Input information ---
NAME=Figure_1
ratio=1:160000
TOPO_STEP=100
OUT_DPI=100

gmt set PS_MEDIA 2500x2500
gmt set PS_PAGE_ORIENTATION landscape
gmt set PS_PAGE_COLOR White
gmt set FONT_TITLE 16p, Helvetica
gmt set FONT_ANNOT 12p, Helvetica
gmt set FONT_LABEL 12p, Helvetica
gmt set MAP_FRAME_TYPE plain



# --- Define plot region and projection ---
region=-17.3/-15.9/64.845/65.35
proj=M25c
gmt mapproject -R$region -J$proj -W > tmp
read w h < tmp

# --- The colour zone ---
gmt makecpt -C$GMTDATA/grey_poss.cpt -T-3500/2500/$TOPO_STEP -Z > topo.cpt


gmt begin plots/$NAME png dpi $OUT_DPI
    echo "   ...plotting topography..."
    gmt grdimage $GMTDATA/IcelandDEM_20m.grd -I$GMTDATA/IcelandDEM_20mI.grd -Ctopo.cpt -R$region -J$proj -X4c -Y8c 

    # -------------------------------------

    echo "   ...plotting fractures..."
    gmt plot $GMTDATA/sNVZ_fractures.xy  -W0.25p,black

    echo "   ...plotting Askja caldera complex..."
    gmt plot $GMTDATA/askja_caldera.xy -Sf0.10/0.085c+l -W0.5p,black

    echo "   ...plotting Askja lakes..."
    gmt plot $GMTDATA/askja_lakes.xy -Gblue@80 -W0.25p,blue

    

    
    echo "   ...adding panel borders, ticks, and compass..."
    # Place north arrow at same height but on the right side of the plot
    gmt basemap -J$proj -R$region -Tdx$(echo "$w-3" | bc)c/$(echo "$h-3" | bc)c+w2c+l,,,N \
        --FONT_ANNOT=16p,Helvetica
    gmt basemap -Lx$(echo "$w-0.5" | bc)c/1c+c65+w10k+lkm+jBR \
        -F+p1p,black+gwhite+c0.1c/0.1c/0.25c/1.4c --FONT_ANNOT=16p,Helvetica  \
        -Bxa0.25df0.125d -Bya0.1df0.05d -BSWne

        echo "S +0.2c t 0.5c red thin,black 0.85c Seismometer" | gmt legend -J$proj -R$region -DjBR+w1.2i+o1.3c/1.3c

    
    
    echo "   ...plotting seismic stations..."
    awk -F ","  ' {print $3,$2}' $Data/station_data/all_network_stations.txt | gmt plot -J$proj -R$region -St0.5 -Gred \
        -Wthinnest,black

    echo "-16.8 65.06 Askja" | gmt pstext -F+f12p,Helvetica
    echo "-16.74 65.03 Osk." | gmt pstext -F+f12p,Helvetica
    




    # ---- Inset Map (Top Left Corner, 6x6cm) ----
    echo "   ...drawing inset map in top left..."

    gmt inset begin -DjTL+w8c/6c+o0.7c/0.7c -F+p0.7p,black+gwhite

        # Draw land (GSHHG default), sea, and borders for all of Iceland
        gmt coast -R-25/-12/63/68 -JM8c -Ggray90 -Sskyblue -Wthinnest,black -Baf

        echo "   ...plotting Askja fissures..."
        gmt plot $GMTDATA/fisswarms_fil.xy  -R-25/-12/63/68 -JM8c  -Gorange@80 -W0.25p,black
        
        
        echo "   ...plotting icecaps..."
        gmt plot $GMTDATA/glaciers.xy  -R-25/-12/63/68 -JM8c  -Gwhite -W0.25p,black

        # Draw red rectangle indicating the main map region
        awk -v r="$region" 'BEGIN{
            split(r,a,"/");
            print a[1],a[3];
            print a[2],a[3];
            print a[2],a[4];
            print a[1],a[4];
            print a[1],a[3];
        }' | gmt plot -R-25/-12/63/67 -JM8c -W1.5p,red

    gmt inset end

gmt end 

if command -v pngquant >/dev/null 2>&1; then
    echo "...compressing PNG with pngquant..."
    pngquant --force --strip --quality=65-90 --output plots/${NAME}.png plots/${NAME}.png
fi

# Additional lossless compression passes if available.
if command -v oxipng >/dev/null 2>&1; then
    echo "...optimizing PNG with oxipng..."
    oxipng -o 4 --strip all plots/${NAME}.png >/dev/null 2>&1
fi

if command -v zopflipng >/dev/null 2>&1; then
    echo "...optimizing PNG with zopflipng..."
    zopflipng -y --lossy_transparent plots/${NAME}.png plots/${NAME}.png >/dev/null 2>&1
fi

if ! command -v pngquant >/dev/null 2>&1 && command -v convert >/dev/null 2>&1; then
    echo "...compressing PNG with ImageMagick PNG8 fallback..."
    convert plots/${NAME}.png -strip -colors 256 PNG8:plots/${NAME}_tmp.png
    mv plots/${NAME}_tmp.png plots/${NAME}.png
fi

echo "...removing temporary files..."
rm tmp gmt.* *.cpt

echo "Complete."

