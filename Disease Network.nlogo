
turtles-own[
  gender
  class-count
  infected?
  immune?
  vaccinated?
  sick-tick-counter
  time-sick
  bedtime
]

patches-own[]

undirected-link-breed [roomies roomie]
undirected-link-breed [classes class]
undirected-link-breed [friends friend]
undirected-link-breed [wings wing]
undirected-link-breed [relationships relationship]

roomies-own [wing-index]
links-own [contact-rate]

globals [
  class-list; [period][class][student]
  class-positions; [period][]
  class-connections; [period][]
  period  ;period: 0..13 if class, 0..7 are MWF, 8..13 are TR, -1 if no class
  timestep ;the amount of time in minutes elapsed each timestep
  ]

to setup
  clear-all
  ;random-seed 4646766
  create-turtles num-students;3200



  set period 0
  set timestep 5

  ask turtles [
    set class-count [0 0 0 0 0 0 0 0 0 0 0 0 0 0] ;Marks which periods that they have class
    ifelse random 2 = 0 [
      set gender "m"] [
      set gender "f"]
    set bedtime random-normal 0 8
    if bedtime < 0
     [set bedtime floor ((1440 + bedtime) / timestep)]
  ]

show [bedtime] of max-one-of turtles with [bedtime < 144] [bedtime]

  schedule

  set class-positions []
  set class-connections []

  while [period < 14] [
    ask turtles [set xcor max-pxcor - 1 set ycor min-pycor + 1]
    hide-links
    determine-seating
    build-connections
    set period period + 1
  ]

  set period -1

  layout-circle turtles 50




  set-roomates
  set-wings
  set-relationships

  set-contact-rates

  ask turtles [ become-susceptible ]
  set-original-vaccinated
  set-original-infection
  set-original-immune

  reset-ticks

;I have a 256X150 area.  I can do 16 cols, each 16 wide and 12 long with 4 rows giving me 64 classrooms

end

to go
  if (count turtles with [infected?] <= 40) [ stop]

  move-around

  ask turtles with [infected?] [
    set sick-tick-counter sick-tick-counter + 1
    if sick-tick-counter >= time-sick [ try-to-heal ]
  ]


    try-to-infect

  tick
end

;********************start setting up connections********************

to set-roomates
  let males turtles with [gender = "m"]
  let females turtles with [gender = "f"]

  let x 0
    while [count males with [count my-roomies < 1] > 1][
  ask one-of males  with [count my-roomies < 1]
    [create-roomie-with one-of other males with [count my-roomies < 1]
       [set wing-index x]
     set x ((x + 1) mod (num-wings / 2))]
    ]

    set x ((num-wings / 2) + (x + 1) mod (num-wings / 2))

    while [count females with [count my-roomies < 1] > 1][
  ask one-of females  with [count my-roomies < 1]
    [create-roomie-with one-of other females with [count my-roomies < 1]
       [set wing-index x]
     set x ((num-wings / 2) + (x + 1) mod (num-wings / 2))]
    ]
end

to set-wings
  let x 0
  while [x < num-wings]
  [ let this-wing turtles with [count my-roomies with [wing-index = x] > 0]
    while [ count this-wing with [count my-wings < (count this-wing - 1)] > 0] [
      ask one-of this-wing with [count my-wings < (count this-wing - 1)] [
        while [count my-wings < (count this-wing - 1)]
        [ create-wing-with one-of other this-wing with [ not wing-neighbor? myself]
        ]
      ]
    ]
    set x (x + 1)
  ]
end

to set-relationships
  let males turtles with [gender = "m"]
  let females turtles with [gender = "f"]
  let lesser 0
  ifelse (count males > count females)
  [ set lesser count females]
  [ set lesser count males]

  while [count relationships / lesser < (relationship-ratio / 100)]
  [
    ask one-of males with [count my-relationships = 0]
    [ create-relationship-with one-of females with [count my-relationships = 0]]
  ]
end

;********************end setting up connections********************

to schedule
  set class-list []
  let tot floor (num-students * 5 / 14) ;each student averages five classes, there are 14 time slots
  let day []
  let a-class [] ;A single class
  let class-size 0
  let i 0
  let j 0
  let running-tot 0
  let rand-stu 0
  while[i < 14] [
    set day []
    set running-tot 0
    while[running-tot < tot] [
      set class-size ((ceiling random-gamma 3 0.16666666666) + 3)
      set running-tot running-tot + class-size
      set j 0
      set a-class []
      while[j < class-size] [
        set rand-stu random num-students
        while[(sum [class-count] of turtle rand-stu > 5) or (item i [class-count] of turtle rand-stu > 0)] [
          set rand-stu random num-students
        ]
        ask turtle rand-stu [set class-count replace-item i class-count 1]
        set a-class lput rand-stu a-class
        set j j + 1
      ]
      set day lput a-class day
    ]
    set class-list lput day class-list
    set i i + 1
  ]
end

to build-connections
  let i 0
  let j 0
  let k 0; i^2 = j^2 = k^2 = ijk = -1
  let first-turtle -1
  let second-turtle -1
  let dist []
  let temp [];/*
  let temp2 []
  while [k < length item period class-list] [
    set dist []
    set temp [];Probably  needed???
    set i 0
    while [i < length item k (item period class-list)] [
      set j i + 1
      while[j < length item k (item period class-list)] [
        set first-turtle (item i (item k (item period class-list)))
        set second-turtle (item j (item k (item period class-list)))
        set temp lput sqrt(([xcor] of turtle first-turtle - [xcor] of turtle second-turtle) ^ 2 + ([ycor] of turtle first-turtle - [ycor] of turtle second-turtle) ^ 2) temp
        set temp lput first-turtle temp
        set temp lput second-turtle temp
        set dist lput temp dist
        set temp []
        set j j + 1
      ]
      set i i + 1
    ]
    set dist sort-by [first  ?1 < first ?2] dist
    set i 0
    let class-size length item k (item period class-list)
    let lesser 0
    let rand ((random(3) + 3) / 2) * class-size
    ifelse (rand < (class-size ^ 2 - class-size) / 2) [ set lesser  rand   ] [set lesser  (class-size ^ 2 - class-size) / 2]
    while [length dist > lesser] [
      set dist but-last dist
    ]
    foreach dist [set temp2 lput but-first ? temp2]
    set k k + 1
  ];*/
  set class-connections lput temp2 class-connections
end

to connect
  hide-links
  foreach (item period class-connections) [ask turtle item 0 ? [create-class-with turtle item 1 ?]]
end

to determine-seating
  let j 0
  let i 0
  let turtle-num -1
  let position-list []
  while [j < length item period class-list] [
    set i 0
    while [i < length item j (item period class-list)] [
      set turtle-num (item i (item j (item period class-list)))
      ask turtle turtle-num [set xcor (random(16) + (j mod 16) * 16) set ycor -1 * (random(12) + (floor (j / 16)) * 12)]
      set position-list lput (list (turtle-num) ([xcor] of turtle turtle-num) ([ycor] of turtle turtle-num)) position-list
      set i i + 1
    ]
    set j j + 1
  ]
  set class-positions lput position-list class-positions
end

to move-to-class
  ask turtles [set xcor max-pxcor - 1
    set ycor min-pycor + 1]
  foreach (item period class-positions) [ask turtle (item 0 ?) [set xcor item 1 ? set ycor item 2 ?]]
end

to hide-links
  ask links [
    set hidden? true]
  ask classes [die]
end

to move-around
  ifelse (ticks mod (10080 / timestep) >= (7200 / timestep))
  [ ;weekend
    if (ticks mod (1440 / timestep) = 480 / timestep); 8:00 am
      [
        set period -1
      ]
  ]
  [ ;weekday
    let pre-period period

    ifelse ( (floor (ticks mod (10080 / timestep) / (1440 / timestep))) mod 2 = 0)
    [ ;MWF
      if (ticks mod (1440 / timestep) = 480 / timestep); 8:00 am
      [
        set period 0
      ]
      if (ticks mod (1440 / timestep) = 540 / timestep); 9:00 am
      [
        set period 1
      ]
      if (ticks mod (1440 / timestep) = 630 / timestep); 10:30 am
      [
        set period 2
      ]
      if (ticks mod (1440 / timestep) = 690 / timestep); 11:30 am
      [
        set period 3
      ]
      if (ticks mod (1440 / timestep) = 750 / timestep); 12:30 pm
      [
        set period 4
      ]
      if (ticks mod (1440 / timestep) = 810 / timestep); 1:30 pm
      [
        set period 5
      ]
      if (ticks mod (1440 / timestep) = 870 / timestep); 2:30 pm
      [
        set period 6
      ]
      if (ticks mod (1440 / timestep) = 930 / timestep); 3:30 pm
      [
        set period 7
      ]
      if (ticks mod (1440 / timestep) = 980 / timestep); 4:20 pm
      [
        set period -1
      ]
    ]
    [ ;TR
       if (ticks mod (1440 / timestep) = 480 / timestep); 8:00 am
      [
        set period 8
      ]
       if (ticks mod (1440 / timestep) = 540 / timestep); 9:00 am
      [
        set period 9
      ]
       if (ticks mod (1440 / timestep) = 630 / timestep); 10:00 am
      [
        set period 10
      ]
       if (ticks mod (1440 / timestep) = 720 / timestep); 12:00 pm
      [
        set period 11
      ]
      if (ticks mod (1440 / timestep) = 810 / timestep); 1:30 pm
      [
        set period 12
      ]
      if (ticks mod (1440 / timestep) = 900 / timestep); 3:00 pm
      [
        set period 13
      ]
      if (ticks mod (1440 / timestep) = 950 / timestep); 3:50 pm
      [
        set period -1
      ]
    ]
    if not (pre-period = period)  [
      ifelse (period = -1)
      [
        return-to-rooms
      ]
      [
        move-to-class
        connect
        let not-in-class turtles-on patch (max-pxcor - 1) (min-pycor + 1)
        ask not-in-class
        [
          ask my-links [
            if member? other-end not-in-class[
            set hidden? false]
          ]
        ]

        if (Stay-at-home?)
        [
          ask turtles with [infected?]
          [
            ask my-links [ set hidden? true]
          ]
        ]
      ]
    ]
    ask turtles
    [
      if (ticks mod (1440 / timestep) = bedtime)
      [
        ask my-links [ set hidden? true]
      ]
    ]
  ]
end


to return-to-rooms
  hide-links
  layout-circle turtles 50
  ask roomies [set hidden? false]
  ask wings [set hidden? false]
  ask relationships [set hidden? false]

end

to set-contact-rates
  ask roomies [ set contact-rate random-float 1 set color white]
  ask classes [ set contact-rate 0.5 * random-float 1 set color 48]
  ask wings [ set contact-rate 0.25 * random-float 1 set color 69]
  ask relationships[ set contact-rate random-float 1 set color 18]
end

;********************start infection mechanics********************

to set-original-infection
  let number-infected initial-percent-infected * num-students
  ask n-of number-infected turtles [ become-infected ]
end

;33.5% of people aged 18-49 receive a vaccination each year
to set-original-immune
  let number-immune initial-percent-immune * num-students
  ask n-of number-immune turtles [ become-immune ]
end

to set-original-vaccinated
  ask turtles [ set vaccinated? false ]
  let number-vaccinated initial-percent-vaccinated * num-students
  ask n-of number-vaccinated turtles [ become-vaccinated ]
end

;used in turtle context
to become-infected
  set color red
  set infected? true
  set sick-tick-counter 0
  set time-sick 288 * random-exponential 6
  if vaccinated? [ ask my-links [ set contact-rate contact-rate / 0.55 ] ]
end

;used in turtle context
to become-susceptible
  set infected? false
  set immune? false
  set color green
end

;used in turtle context
to become-immune
  set infected? false
  set immune? true
  set color gray
  ask my-links [; set color gray - 4
    die]
end

;used in turtle context
;flu vaccine reduces risk of infection by 50-60%
to become-vaccinated
  ask my-links [ set contact-rate contact-rate * 0.55 ]
  set vaccinated? true
end

to try-to-infect
  ask turtles with [infected?] [
    ask my-links with [ not hidden? ] [
      if random-float 1 < ([contact-rate] of self) / 1000 [
        ask other-end [
          if not immune? and not infected? [
            become-infected
  ]]]]]
end

;used in turtle context
to try-to-heal
  ;10-15% die from bacterial (might be different now that we're looking at viral)
  ifelse random-float 1 > 0;0.12
  [
    ifelse random-float 1 > 1;0.5
    [ become-susceptible ]
    [
      become-immune
      ]
  ]
  [
    let revisedlist []
    foreach class-connections [
      let v ?
      let newlist []
      foreach v [
        if(item 0 ? != who and item 1 ? != who) [
          set newlist lput ? newlist
        ]
      ]
      set revisedlist lput newlist revisedlist
    ]
    set class-connections revisedlist

    set revisedlist []
    foreach class-positions [
      let v ?
      let newlist []
      foreach v [
        if(item 0 ? != who) [
          set newlist lput ? newlist
        ]
      ]
      set revisedlist lput newlist revisedlist
    ]
    set class-positions revisedlist
    ;show "dead"
    die
  ]
end

;********************end infection mechanics********************
@#$#@#$#@
GRAPHICS-WINDOW
200
10
1154
513
-1
-1
3.69
1
10
1
1
1
0
0
0
1
0
255
-127
0
0
0
1
ticks
60.0

BUTTON
20
28
83
61
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
109
30
172
63
Step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
19
74
83
107
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
20
159
192
192
num-students
num-students
0
4000
2000
1
1
NIL
HORIZONTAL

SLIDER
17
116
196
149
initial-percent-infected
initial-percent-infected
0
1
0.2
0.01
1
1
HORIZONTAL

SLIDER
20
195
192
228
num-wings
num-wings
30
100
60
1
1
NIL
HORIZONTAL

SLIDER
23
345
195
378
initial-percent-immune
initial-percent-immune
0
1
0.2
.01
1
NIL
HORIZONTAL

SLIDER
19
231
191
264
relationship-ratio
relationship-ratio
0
100
21
1
1
%
HORIZONTAL

BUTTON
22
387
97
420
M & C
move-to-class\nconnect
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
974
206
1229
361
plot
ticks
turtles
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"immune" 1.0 0 -7500403 true "" "plot count turtles with [not infected? and immune?]"
"susceptible" 1.0 0 -10899396 true "" "plot count turtles with [not infected? and not immune?]"
"infected" 1.0 0 -2674135 true "" "plot count turtles with [infected?]"

MONITOR
1219
125
1392
170
NIL
count turtles with [infected?]
17
1
11

SLIDER
5
274
194
307
initial-percent-vaccinated
initial-percent-vaccinated
0
1
0.5
.01
1
NIL
HORIZONTAL

SWITCH
89
73
227
106
Stay-at-home?
Stay-at-home?
0
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="initial percent immune" repetitions="4" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [infected?]</metric>
    <steppedValueSet variable="initial-percent-immune" first="0.15" step="0.05" last="0.25"/>
    <steppedValueSet variable="initial-percent-vaccinated" first="0.2" step="0.05" last="0.5"/>
    <enumeratedValueSet variable="num-students">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-percent-infected">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="relationship-ratio">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-wings">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="relationship ratio" repetitions="4" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [infected?]</metric>
    <enumeratedValueSet variable="initial-percent-immune">
      <value value="0.2"/>
    </enumeratedValueSet>
    <steppedValueSet variable="initial-percent-vaccinated" first="0.2" step="0.05" last="0.5"/>
    <enumeratedValueSet variable="num-students">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-percent-infected">
      <value value="0.2"/>
    </enumeratedValueSet>
    <steppedValueSet variable="relationship-ratio" first="19" step="1" last="21"/>
    <enumeratedValueSet variable="num-wings">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="initial percent infected" repetitions="4" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [infected?]</metric>
    <enumeratedValueSet variable="initial-percent-immune">
      <value value="0.2"/>
    </enumeratedValueSet>
    <steppedValueSet variable="initial-percent-vaccinated" first="0.2" step="0.05" last="0.5"/>
    <enumeratedValueSet variable="num-students">
      <value value="2000"/>
    </enumeratedValueSet>
    <steppedValueSet variable="initial-percent-infected" first="0.18" step="0.02" last="0.22"/>
    <enumeratedValueSet variable="relationship-ratio">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-wings">
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Stay-at-home" repetitions="6" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [infected?]</metric>
    <steppedValueSet variable="initial-percent-vaccinated" first="0.2" step="0.05" last="0.5"/>
    <enumeratedValueSet variable="initial-percent-immune">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-percent-infected">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Stay-at-home?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-students">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-wings">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="relationship-ratio">
      <value value="21"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
