# --- i/o paths ---
GMTDATA=../../gmt_data
DATA=../../Data
! [ -d plots ] && mkdir plots







##### NEW GRID STUFF ####











# --- Input information ---
NAME=Figure_2
ratio=1:160000
OUT_DPI=100

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



#Max Lat = 65.38205
#Min Lat = 64.76347
#Max Lat = -15.08544
#Min Lon = -17.49961
# --- Define plot region and projection ---
region=-17.1/-16.3/64.85/65.25
proj=M25c
gmt mapproject -R$region -J$proj -W > tmp
read w h < tmp




# --- The colour zone ---
gmt makecpt -C$GMTDATA/grey_poss.cpt -T-3500/2500/100 -Z > topo.cpt
gmt makecpt -Cmagma -T0/1/0.001 -Ic > fast.cpt
gmt makecpt -Cmagma -T0/10/0.1   > swa.cpt
gmt makecpt -Cmagma -T-90/90/5 > fastaxis.cpt
gmt makecpt -Cpolar -T-2.5/2.5/0.05 > strain.cpt
gmt makecpt -Cmagma -T-0.9/10/0.05 -A50 > depthkm.cpt



gmt begin plots/$NAME png dpi $OUT_DPI
    echo "   ...plotting topography..."
    gmt grdimage $GMTDATA/IcelandDEM_20m.grd -I$GMTDATA/IcelandDEM_20mI.grd -Ctopo.cpt -R$region -J$proj -X4c -Y8c 

   





   
   
   
    
    echo "   ...plotting fractures..."
    gmt plot $GMTDATA/sNVZ_fractures.xy  -W0.25p,black

    echo "   ...plotting Askja caldera complex..."
    gmt plot $GMTDATA/askja_caldera.xy -Sf0.10/0.085c+l -W0.5p,black



    



    echo "   ...plotting rectangle..."
    gmt plot -J$proj -R$region -W1p,red << EOF
-17 64.91
-16.48 64.91
-16.48 65.2
-17 65.2
-17 64.91
EOF

    #Plot earthquakes
    echo "... plotting inside grid earthquakes..."
    awk -F "," ' {print $3, $4, $5}' $DATA/eq_catalogues/earthquake_catalogue.csv | gmt plot  -J$proj -R$region -Sc0.1 -Cdepthkm.cpt -t90
    

    #Plot earthquakes
    echo "... plotting outside grid earthquakes..."
    awk -F "," ' {print $3, $4, $5}' $DATA/eq_catalogues/outside_grid_earthquakes.csv | gmt plot  -J$proj -R$region -Sc0.1  -Ggreen@90
    

    echo "   ...adding panel borders, ticks, and compass..."
    gmt basemap -J$proj -R$region -Tdx2c/$(echo "$h-3" | bc)c+w2c+l,,,N \
        --FONT_ANNOT=16p,Helvetica
    gmt basemap -Lx$(echo "$w-0.5" | bc)c/1c+c65+w10k+lkm+jBR \
        -F+p1p,black+gwhite+c0.1c/0.1c/0.25c/2.4c --FONT_ANNOT=16p,Helvetica  \
        -Bxa0.25df0.125d -Bya0.1df0.05d -BSWne

    

    echo "S +0.3c t 0.7c red thick,black 1.2c Seismometer" | gmt legend -J$proj -R$region -DjBR+w1.7i+o2.7c/1.3c --FONT_ANNOT_PRIMARY=18p,Helvetica



    awk -F "," ' {print $3, $5, $5}' $DATA/eq_catalogues/earthquake_catalogue.csv | gmt plot -JX$w/-4c -R-17.1/-16.3/-3/10 -Sc0.1c -Cdepthkm.cpt -Y-5c -t90

    gmt basemap -JX$w/-4c -R-17.1/-16.3/-3/10 -Bxa2df1d+l"Longitude" -Bya5f1+l"Depth (km)" -BNWse 

    awk -F "," ' {print $5, $4, $5}' $DATA/eq_catalogues/earthquake_catalogue.csv | gmt plot -JX4c/$h -R-3/10/64.85/65.25 -Sc0.1c -Cdepthkm.cpt -X$(echo "$w+0.5" | bc) -Y5c -t90
    
    gmt basemap -JX4c/$h -R-3/10/64.85/65.25 -Bxa2df1d+l"Depth (km)" -Bya5f1+l"Latitude" -BNWse 
    
    
    echo "   ...plotting seismic stations..."
    awk -F ","  ' {print $3,$2}' $DATA/station_data/used_stations.txt | gmt plot -J$proj -R$region -St0.5 -Gred -X$(echo "-$w-0.5" | bc)\
        -Wthinnest,black

    
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
rm tmp   gmt.* *.cpt

echo "Complete."