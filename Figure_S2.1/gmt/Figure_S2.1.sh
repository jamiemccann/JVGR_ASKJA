# --- i/o paths ---
GMTDATA=/raid2/jam247/Askja_Final/gmt_data
! [ -d plots ] && mkdir plots



# --- Input information ---
NAME=Figure_S2.1
ratio=1:160000
OUT_DPI=100
TOPO_STEP=10
RAYPATH_TRANSPARENCY=90

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


gmt makecpt -C$GMTDATA/grey_poss.cpt -T-3500/2500/$TOPO_STEP -Z > topo.cpt


# --- Define plot region and projection ---
region=-17.02/-16.45/64.9/65.2
proj=M25c
gmt mapproject -R$region -J$proj -W > tmp
read w h < tmp
ratio=1:160000

gmt begin plots/$NAME png dpi $OUT_DPI

    echo "   ...plotting topography..."
    gmt grdimage /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/IcelandDEM_20m.grd -I/raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/IcelandDEM_20mI.grd -Ctopo.cpt -R$region -J$proj -X4c -Y8c 

    # echo "-16.8 65.05 Askja" | gmt pstext -F+f12p,Helvetica
    # echo "-16.347 65.197 Herðubreið" | gmt pstext -F+f12p,Helvetica

    gmt psxy /raid2/jam247/A_Askja_Paper/PAPER_FIGURES/Figure_S2.1/raypaths/raypaths.xy -Wthinnest,black -t${RAYPATH_TRANSPARENCY} -J$proj -R$region 

    echo "   ...plotting check..."
    # gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/sNVZ_fractures.xy -W0.25p,black

    echo "   ...plotting Askja caldera complex..."
    gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/askja_caldera.xy -Sf0.10/0.085c+l -W0.5p,black

    echo "plotting askja lakes"
    # gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/askja_lakes.xy -Gblue@80

    echo "plotting askja roads"
    # gmt plot /raid2/jam247/A_Askja_Writeup/Plotting/GMT/gmt_data/roads_updated.xy -W0.25p,black



    
    # --- Basemap issues ---
    #
    # Basemap may not plot correctly if:
    # 1. The -R and -J supplied to basemap are different from those used in the previous plot commands.
    # 2. The panel position is shifted with -X or -Y (as above, -X4c -Y8c in grdimage, and -X in other plots).
    # 3. Multiple -X translations accumulate and subsequently basemap is "offscreen".
    # 4. The plot region or size is mismatched due to calculated $w $h, leading to elements possibly being off the page.
    # 5. Grouped commands in 'gmt begin' and 'gmt end' need all layers to remain inside the begin/end block with consistent -R/-J.
    #
    # To debug, you can try:
    # - Removing all -X and -Y options except on the FIRST plot command to avoid cumulative shifts.
    # - Ensuring all gmt plot, gmt psxy, and gmt basemap use SAME -R$region and -J$proj.
    # - Plot basemap FIRST after background/DEM before adding content, so you see if/where borders/ticks appear.
    # - Try plotting only the basemap with no other layers to check if it appears.
    #
    # Example test: try running only this inside begin/end:
    # gmt basemap -R$region -J$proj -B
    #
    # Also try forcing -X0 -Y0 on basemap to reset panel location.

    echo "   ...adding panel borders, ticks, and compass..."
    # Make sure not to over-shift with -X or -Y before basemap
    gmt basemap -J$proj -R$region -Tdx2c/$(echo "$h-3" | bc)c+w2c+l,,,N --FONT_ANNOT=16p,Helvetica
    gmt basemap -J$proj -R$region -Lx$(echo "$w-0.5" | bc)c/1c+c65+w10k+lkm+jBR \
        -F+p1p,black+gwhite+c0.1c/0.1c/0.25c/2.0c --FONT_ANNOT=16p,Helvetica  \
        -Bxa0.25df0.125d -Bya0.1df0.05d -BSWne

    echo "S +0.2c t 0.7c red thick,black 1.2c Seismometer" | gmt legend -J$proj -R$region -DjBR+w1.6i+o4.0c/1.3c --FONT_ANNOT=18p,Helvetica --FONT_LABEL=18p,Helvetica


    echo "   ...plotting seismic stations..."
    awk -F ","  ' {print $3,$2}' /raid2/jam247/A_Askja_Paper/Data/stations/stations_smallgrid.txt | gmt plot -J$proj -R$region -St0.5 -Gred \
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
rm tmp gmt.*

echo "Complete."