# --- i/o paths ---
GMTDATA=../../gmt_data
Data=../../Data
! [ -d plots ] && mkdir plots



# --- Input information ---
NAME=Figure_3
ratio=1:160000

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
region=-17.3/-15.9/64.845/65.35
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

#gmt makecpt -Cmagma -T0/0.5/0.01 > strain.cpt

gmt makecpt -Cpolar -T-2.5/2.5/0.05 > strain.cpt



gmt begin plots/$NAME png dpi 150
    echo "   ...plotting topography..."
    gmt grdimage $GMTDATA/IcelandDEM_20m.grd -I$GMTDATA/IcelandDEM_20mI.grd -Ctopo.cpt -R$region -J$proj -X4c -Y8c 

    

    echo "-16.841 65.043 Askja" | gmt pstext -F+f12p,Helvetica

 
    echo "   ...plotting fractures..."
    gmt plot $GMTDATA/sNVZ_fractures.xy  -W0.25p,black

    echo "   ...plotting Askja caldera complex..."
    gmt plot $GMTDATA/askja_caldera.xy -Sf0.10/0.085c+l -W0.5p,black

    echo "plotting askja lakes"
    gmt plot $GMTDATA/askja_lakes.xy -Gblue@80

    


   
    # Plot rift segments as thick red lines (fixed)
	echo "plotting rift segments"
	gmt plot -J$proj -R$region -W5p,green << EOF
-17.000 64.810
-16.400 65.400
>
-16.650 64.650
-16.050 65.050
>
-17.464 64.600
-17.070 64.930
>
-16.750 65.300
-16.600 65.500
EOF

    # Label each green line segment with optional per-label rotation.
    # Set angle to "" for no rotation, or to a degree value (e.g., 56).
    angle_kverkfjell=56
    angle_askja=64
    angle_bardabunga=63
    angle_krafla=71

    plot_label () {
        local lon="$1" lat="$2" text="$3" angle="$4"
        if [ -n "$angle" ]; then
            echo "$lon $lat $text" | gmt pstext -J$proj -R$region -F+f12p,Helvetica-Bold,darkgreen+a${angle}+jCM
        else
            echo "$lon $lat $text" | gmt pstext -J$proj -R$region -F+f12p,Helvetica-Bold,darkgreen+jCM
        fi
    }

    plot_label -16.3 64.9 "Kverkfjell RS" "$angle_kverkfjell"
    plot_label -16.67 65.16 "Askja RS" "$angle_askja"
    plot_label -17.13 64.90 "Bardabunga RS" "$angle_bardabunga"
    plot_label -16.755 65.32 "Krafla RS" "$angle_krafla"
    




    # Draw the central blue circle first
    echo "-16.778 65.050" | gmt plot -Sc1.0c -W1p,black -Gblue -J$proj -R$region

    # Plot 8 blue arrows on an equal-radius ring around the source, all pointing inward.
    center_lon=-16.778
    center_lat=65.050
    ring_radius_deg=0.030
    arrow_len=0.9c
    for bearing in 0 45 90 135 180 225 270 315; do
        read lon lat az << EOF
$(awk -v clon="$center_lon" -v clat="$center_lat" -v r="$ring_radius_deg" -v b="$bearing" 'BEGIN {
    pi = atan2(0, -1)
    br = b * pi / 180.0
    # Local ENU approximation for a small ring around the center.
    lon = clon + (r * sin(br)) / cos(clat * pi / 180.0)
    lat = clat +  r * cos(br)
    az  = b + 180.0
    if (az >= 360.0) az -= 360.0
    printf "%.6f %.6f %.1f\n", lon, lat, az
}')
EOF
        echo "$lon $lat $az $arrow_len" | gmt plot -J$proj -R$region -SV0.6c+e+a30+gblue -W1p,blue
    done









    

    #
	
    # # Arrow 1: azimuth 85°
    # echo "-16.66 65.15 -20 1.2c" | gmt plot -J$proj -R$region -Sv0.5c+e+a30+gred -W1p,red
    # # Arrow 2: azimuth 85° (opposite of Arrow 1)
    # echo "-16.66 65.15 160 1.2c" | gmt plot -J$proj -R$region -Sv0.5c+e+a30+gred -W1p,red

    # # Top short rift segment: opposing red arrows
    # echo "-16.742 65.31 -20 1.2c" | gmt plot -J$proj -R$region -Sv0.5c+e+a30+gred -W1p,red
    # echo "-16.742 65.31 160 1.2c" | gmt plot -J$proj -R$region -Sv0.5c+e+a30+gred -W1p,red



    # # Arrow 1: azimuth 85°
    # echo "-16.863 64.95 -20 1.2c" | gmt plot -J$proj -R$region -Sv0.5c+e+a30+gred -W1p,red
    # # Arrow 2: azimuth 85° (opposite of Arrow 1)
    # echo "-16.863 64.95 160 1.2c" | gmt plot -J$proj -R$region -Sv0.5c+e+a30+gred -W1p,red


    # # Arrow 1: azimuth 85°
    # echo "-17.08 64.92 -20 1.2c" | gmt plot -J$proj -R$region -Sv0.5c+e+a30+gred -W1p,red
    # # Arrow 2: azimuth 85° (opposite of Arrow 1)
    # echo "-17.08 64.92 160 1.2c" | gmt plot -J$proj -R$region -Sv0.5c+e+a30+gred -W1p,red


    # # Arrow 1: azimuth 85°
    # echo "-16.25 64.92 -30 1.2c" | gmt plot -J$proj -R$region -Sv0.5c+e+a30+gred -W1p,red
    # # Arrow 2: azimuth 85° (opposite of Arrow 1)
    # echo "-16.25 64.92 150 1.2c" | gmt plot -J$proj -R$region -Sv0.5c+e+a30+gred -W1p,red


        echo "   ...plotting rectangle..."
    gmt plot -J$proj -R$region -W1p,red << EOF
-17 64.91
-16.48 64.91
-16.48 65.2
-17 65.2
-17 64.91
EOF



    
    
    gmt basemap -J$proj -R$region -Tdx3c/$(echo "$h-3" | bc)c+w2c+l,,,N \
        --FONT_ANNOT=16p,Helvetica 

    
    gmt basemap -Lx$(echo "$w-0.3" | bc)c/$(echo "$h-2.9" | bc)c+c65+w20k+lkm+jTR \
         -F+p1p,black+gwhite+c0.02c/0.02c/0.25c/2.8c --FONT_ANNOT=14p,Helvetica  \
        -Bxa0.25df0.125d -Bya0.1df0.02d -BSWne
	

    
    # First, add the blue circle symbol 1cm above the original legend position (increase y offset by 1cm)
    echo "S 0.25c c 0.25c blue thick,blue 1c     Deflation Source" | gmt legend -J$proj -R$region -DjTR+w1.2i+o3.0c/0.8c
    # Then add the original Rift Segment symbol legend
    echo "S +0.5c - 0.6c green thickest,green 1.5c     Rift Segment" | gmt legend -J$proj -R$region -DjTR+w1.2i+o3.0c/1.8c
    

gmt end 

echo "...removing temporary files..."
rm tmp gmt.* *.cpt

echo "Complete."