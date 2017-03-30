;
; January 2015
; Wageningen UR, Centre for Geo-information
; Arend Ligtenberg: arend.ligtenberg@wur.nl
; For demonstration and education purposes only
;;============================================

;;TODO:
;;Ensure max water height by breach
;;Use slope for getting each neighbour's flow potential


extensions [gis]

patches-own
[
  elevation
  roughness
  waterHeight
  water
  depth
  difference
  incomingWater
  outgoingWater
  differences
  maxHeight
]

turtles-own
[
  water-height
]

globals
[
  ahn
  rough
  border
  exp-count
  elevationDataSetName
  roughnessDataSetName
  exportGridName
  breachheight
]


;;SOME BASIC SETTINGS
;;===================
to init

  ;;the input elevation grid
  ;;-------------------------
  set elevationDataSetName "./data/defaultdem.asc"

  ;;the input roughness grid
  ;;........................
   set roughnessDataSetName "./data/rough-100-lmw.asc"

  ;;name of the export grids showing the results of the flooding (will be postfixed by the clocktick)
  ;;-------------------------------------------------------------------------------------------------
  set exportGridName "./result/"  ;;path need to exist!



  ;; the default waterheight at the dam
  ;;----------------------------------------
  set breachHeight 1;
  ;;ask patch x-breach y-breach [
  ;;  set maxHeight (elevation + breachHeight)
  ;;]
  ask patches [set maxHeight 1000]
  reset-ticks

 end





;; START OF THE DYNAMIC MODEL CALCULATIONS (clicking the "go" button)
;;===================================================================
to go
 runmodel
 tick
end
;; MAIN PROCEDURE FOR CALLING ALL OTHER PROCEDURES AND MANAGING PROCESS
;;---------------------------------------------------------------------
to runmodel
  check-status
  set-breach
  settle-outgoing-water
  calculate-incoming-water
  check-max-height
  ask patches [set difference 0]
  check-color
end

to check-status
  ask patches[
    if waterHeight > 0[
    set pcolor blue
    ]
  ]
end

to set-breach
  ask patch x-breach y-breach [
    set pcolor blue
    set waterHeight waterHeight + breachheight
    ]
end

to settle-outgoing-water
  ;; If there was a difference in height, 50% of the water column is distributed to that cell
  ask patches[
    if outgoingWater > 0 [
      set outgoingWater (outgoingWater + (waterHeight / 2))
      set waterHeight (waterHeight - (waterHeight / 2))
      set differences 0
    ]
  ]
end

to calculate-incoming-water
  ask patches with [pcolor = blue][
    let centerHeightDif elevation + waterHeight
    let centerWaterHeight waterHeight
    let outW outgoingWater
    let cellCenterDifferences differences

     ask  neighbors [
      ;; Calculate height difference to see if cell is applicable
      if elevation + waterHeight < centerHeightDif [
        set difference centerHeightDif - (elevation + waterHeight)
        set cellCenterDifferences cellCenterDifferences + difference
      ]
      ;; Let 50% of the water of the center cell flow out at maximum
      ;; If a cel lcenter is higher than a particular neighbour, it gets its portion assigned to it
      if elevation + waterHeight < centerHeightDif[
        set incomingWater (difference / cellCenterDifferences) * ((centerWaterHeight / 2) + outW)
        ]
       
        ;;[set incomingWater 0]
      ]
 ]
end

to settle-incoming-water
  ask patches[
    set waterHeight (waterHeight + incomingWater)
    set incomingWater 0  

to check-max-height
  ask patches[
    set waterHeight (waterHeight + incomingWater)
    set incomingWater 0
    let localHeight (waterHeight + elevation)
    if (localHeight) > maxHeight[
       set outgoingWater outgoingWater + (localHeight - maxHeight)
       set waterHeight waterHeight - (localheight - maxHeight)
      ]
    ]
end

to check-color
  ask patches [
    ifelse waterHeight > 250
      [set pcolor 102]
      [ifelse waterHeight > 150
        [set pcolor 104]
        [ifelse waterHeight > 50
          [set pcolor 95]
          [ifelse waterHeight > 0
            [set pcolor 83]
            [if pcolor = blue[
                if waterHeight <= 0 [set pcolor red]
              ]
            ]
          ]
        ]
      ]
  ]
end







;;===================================================================================================================================================
;; BELOW ARE JUST CONVIENIANCE ROUTINES AND SETTING THAT PROVIDE FOR IMPORTING AND EXPORTING AND VISUALIZING GEODATA
;; YOU DON'T NEED TO CHANGE MUCH HERE FOR THE CASE OF 'LAND VAN MAAS AND WAAL'
;;===================================================================================================================================================



;;THIS IS WHAT HAPPENS IF YOU CLICK THE RESET BUTTON
;;==================================================
to reset
  clear-drawing
  clear-turtles
  clear-all-plots
  reset-ticks
  ;file-close-all
  set exp-count 1
  end


;;LOADING EN COLORRAMPING ARCGIS GRIDs
;;================================================
to loaddata
 clear-patches
 init

 show "loading elevation from file..."
 set ahn gis:load-dataset elevationDataSetName
 show word "rows: "gis:height-of ahn
 show word "columns: "gis:width-of ahn


   ;;set the dimensions of the NetLogo world based on the input data
 ;;----------------------------------------------------------------
 resize-world 0 gis:width-of ahn (gis:height-of ahn - (2 * gis:height-of ahn)) 0


 ;; get the min and max elevation just we need it
 ;; to tune the color ramping of the elevation data
 ;;----------------------------------------------------
 let min-elevation gis:minimum-of ahn
 let max-elevation gis:maximum-of ahn
 show word "lowest :" min-elevation
 show word "highest :" max-elevation


 ;;put everything (elevation en roughness on the netlogo
 ;;world. You need to enter the right extend of the world
 ;;beforehand throught the gui as netlogo does not allow
 ;;you to do by scripting
 ;;----------------------------------------------------------------
 gis:set-world-envelope (gis:raster-world-envelope ahn 0 0)
 gis:apply-raster ahn elevation

 ;;some hacking with coloring to create a 'nice' map
 ;;eliminate the "stuwwal" its affect the color ramping
 ;;----------------------------------------------------
 ask patches
 [
   if elevation > 2000 [set elevation 1500]
 ]

 ;;use the scale-color operator to assign colors based
 ;;on the elevation
 ;;---------------------------------------------------
 ask patches
 [
  if (elevation > -9999)
  [
    set pcolor scale-color brown elevation min-elevation 2000

  ]
  if  isNaN(elevation)
  [
   set pcolor black
   set elevation max-elevation + breachheight
  ]
 ]
  set-default-shape turtles "square"
  show "done loading data"


  set border patches with [ count neighbors != 8 ]


  ;;loading roughness data
  ;;-----------------------
 show "loading roughness from file..."
 set rough gis:load-dataset roughnessDataSetName
 gis:apply-raster rough roughness

end







to-report isNaN [x]
  report not ( x > 0 or x < 0 or x = 0 )
end

;;EXPORT THE FLOODING GRIDS TO ARCGIS FORMAT
;;=========================================
to do-export
   if export-frequentie > 0
    [
       if (exp-count = export-frequentie)
        [
           show "exporting to grid"
           ;;create raster data set according the input ahn
           ;;-----------------------------------------------
           let dummy gis:create-raster gis:width-of ahn gis:height-of ahn  (gis:envelope-of ahn)
           let x 0
           repeat (gis:width-of dummy)
           [
             let y 0
             repeat (gis:height-of dummy)
             [
               if patch x y != nobody
               [
                 ifelse [elevation] of patch x y  > 0
                 [
                   ifelse any? turtles-on patch x y
                   [
                     let waterTurtles turtles-on patch x y
                     gis:set-raster-value dummy x abs y  max [water-height] of waterTurtles
                   ]
                   [
                     gis:set-raster-value dummy x abs y -9999
                   ]
                  ]
                  [
                    gis:set-raster-value dummy x abs y -9999
                  ]
                ]
                   set y  y - 1
              ]
                set x x + 1
              ]

           gis:store-dataset dummy word exportGridName ticks
           set exp-count 0
        ]
           set exp-count exp-count + 1
       ]
end
