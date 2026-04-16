# --- i/o paths ---
GMTDATA=../../gmt_data
Data=../data
! [ -d plots ] && mkdir plots



# --- Input information ---
NAME=Figure_10
ratio=1:160000

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

# --- Define plot region and projection ---
region=-17.02/-16.45/64.9/65.2
proj=M25c
gmt mapproject -R$region -J$proj -W > tmp
read w h < tmp
ratio=1:160000


# --- The colour zone ---
gmt makecpt -C$GMTDATA/grey_poss.cpt -T-3500/2500/1 -Z > topo.cpt
gmt makecpt -Cmagma -T0/6/0.01   > swa.cpt


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
    xoff=`echo $xoff - 0.5 | bc -l`; yoff=`echo $yoff - 0.5 | bc -l`

    # Using -Xa and -Ya reverts plot position after the offset and plot
    awk -F "," 'FNR > 1 {print 1,$24}' $3 | gmt rose -I -T > tmprose.stats  # CHANGE $20 TO CORRECT COLUMN VAL - EXPECTS HEADER
    read N MAZ MR MRL MBS SM LLS < tmprose.stats
    rm tmprose.stats
    clr=`awk -v mrl="$MRL" '{if ($1<=mrl && $3>mrl) {print $2}}' fast.cpt`
    awk -F "," 'FNR > 1 {print $24}' $3 | gmt rose -R0/0.001/0/360 -B+w0.01 -Gred@10 -i0 -Sn0.5c -JX1. -T -L -A15 -Xa$xoff -Ya$yoff -W0.5,red
}

gmt begin plots/$NAME png dpi 150
    echo "   ...plotting topography..."
    gmt grdimage $GMTDATA/IcelandDEM_20m.grd -I$GMTDATA/IcelandDEM_20mI.grd -Ctopo.cpt -R$region -J$proj -X4c -Y8c 

    

    # echo "-16.8 65.05 Askja" | gmt pstext -F+f12p,Helvetica
    # echo "-16.347 65.197 Herðubreið" | gmt pstext -F+f12p,Helvetica
    # # echo "-16.46 64.985 Vaðalda" | gmt pstext -F+f12p,Helvetica

    

    

    

    echo "   ...plotting fractures..."
    gmt plot $GMTDATA/sNVZ_fractures.xy  -W0.25p,black

    echo "   ...plotting Askja caldera complex..."
    gmt plot $GMTDATA/askja_caldera.xy -Sf0.10/0.085c+l -W0.5p,black

    echo "plotting askja lakes"
    gmt plot $GMTDATA/askja_lakes.xy -Gblue@80

    echo "plotting askja roads"
    gmt plot $GMTDATA/roads_updated.xy -W0.25p,black

    
    
    
     


    # Create interpolated grid of SWA values, limited to data coverage area
    # 1. Extract points where there is SWA data (column 4 > 100)
    awk -F',' '!/^#/ && $4 > 1000 {print $1, $2, $3}' ../gridding_script/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2/ACl_FILTERED_DATA_04_xinc2km_yinc2km_weighting_inv_dist2_grid_cells_SWA_source_to_station_averages.txt > swa_tmp.xyz

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






    
   


    

    






    echo "   ...adding panel borders, ticks, and compass..."
    gmt basemap -J$proj -R$region -Tdx2c/$(echo "$h-3" | bc)c+w2c+l,,,N \
        --FONT_ANNOT=16p,Helvetica 
    
    # Make a single white box to fit both the 10km scale bar and SWA scale bar, then plot both within this frame
    # Box: enough height for both; tall enough, shifted right to match scale-bar x, a bit wider
    # We'll use -F+p1p,black+gwhite+c0.02c/0.02c/0.12c/2.5c for a taller box (2.5c tall)
    gmt basemap -Lx$(echo "$w-0.3" | bc)c/1c+c65+w10k+lkm+jBR \
         -F+p1p,black+gwhite+c0.02c/0.02c/0.12c/2.5c --FONT_ANNOT=14p,Helvetica  \
        -Bxa0.25df0.125d -Bya0.1df0.02d -BSWne

    # 10km scalebar is at x=$(echo "$w-0.3" | bc)c, y=1c, anchored at jBR

    # Now add the SWA scale bar, centre it with the scale bar (same x as above), below it (further up from bottom right)
    # Move psscale up relative to -L's anchor: (1c + margin), try at 2.1c above bottom
    echo "   ...adding scale bar..."
    gmt psscale -Dx$(echo "$w-5.0" | bc)c/2.1c+jCM+w5c/0.4c+e+h+ml \
        --MAP_TICK_LENGTH=0.1c \
        --FONT_ANNOT_PRIMARY=16p,Helvetica --FONT_LABEL=16p,Helvetica \
        -Cswa.cpt -Bpa1f1+l"SWA (%)" -G0/6
   

gmt end 

echo "...removing temporary files..."
rm -f tmp gmt.* swa_tmp.xyz swa_hull.xy swa_mask.grd swa_tmp.grd swa_masked.grd *.cpt 2>/dev/null

echo "Complete."