# NewFloor1 map generator: layout + wall autotiler + floor detail (Phases 2-4).
# Run: powershell -File Tests\Tools\newfloor1_maps.ps1
# Writes one JSON per layer (map + legend + origin) to user://floor_maps
# (%APPDATA%\Godot\app_userdata\Sinfulness\floor_maps). Paint each layer in the editor with
# sintiles_paint { node_path, clear_first: true, map_file: "user://floor_maps/<name>.json" },
# FloorShade with sintiles_terrain using the regions in shade_regions.json. See
# Tests/PRDs/NewFloor1_Handoff.md.
# Layout chars: '#' wall, '.' floor, 'D' door cell (walkable, drawn as arch / arch top),
# 'N' niche floor cell (walkable recess), 'G' gate cell (decorative, wall),
# 'W' water, 'P' platform strip around the pool.
$W = 64; $H = 48
$out = "$env:APPDATA\Godot\app_userdata\Sinfulness\floor_maps"; New-Item -ItemType Directory -Force $out | Out-Null
$g = New-Object 'char[,]' $H, $W
for ($y = 0; $y -lt $H; $y++) { for ($x = 0; $x -lt $W; $x++) { $g[$y, $x] = '#' } }
function Rect($x0, $y0, $x1, $y1, [char]$c = '.') { for ($y = $y0; $y -le $y1; $y++) { for ($x = $x0; $x -le $x1; $x++) { $script:g[$y, $x] = $c } } }

# Rooms
Rect 4 34 15 42; Rect 12 34 15 37 '#'                    # R1 entrance
Rect 20 18 41 33; Rect 20 18 24 21 '#'; Rect 37 30 41 33 '#'   # R2 hall
Rect 46 22 59 35                                         # R3 water
Rect 46 5 59 14                                          # R4 stairs down
Rect 4 6 14 15; Rect 11 6 14 9 '#'                       # R5 side room
Rect 22 5 36 11                                          # R6 north room
Rect 46 40 57 45; Rect 54 40 57 42 '#'                   # R7 side room
Rect 26 39 33 44                                         # R8 closet
# Corridors (side entries 3 wide, north entries 2 wide through a door)
Rect 16 38 23 40; Rect 21 34 23 37                       # R1 -> R2 (enters R2 from the south)
Rect 42 26 45 28                                         # R2 -> R3
Rect 37 8 45 10                                          # R4 -> R6
Rect 28 12 29 13; Rect 28 14 29 17 'D'                   # R6 -> R2, door in R2 north wall
Rect 29 34 30 34; Rect 29 35 30 38 'D'                   # R2 -> R8, door in R8 north wall
Rect 50 36 51 39 'D'                                     # R3 -> R7, door in R7 north wall
Rect 51 15 52 17; Rect 51 18 52 21 'D'                   # R4 -> R3, door in R3 north wall
Rect 8 16 9 29; Rect 8 30 9 33 'D'                       # R5 -> R1, door in R1 north wall
# Door styles by left column: open arch 'o' or dark arch 'k'
$doorStyle = @{ '28,14' = 'o'; '29,35' = 'o'; '50,36' = 'o'; '51,18' = 'o'; '8,30' = 'o' }
# Torch niches: niche floor cell (x, r-1) where r is the room's top floor row
$niches = @(@(5, 33), @(33, 17), @(48, 21), @(49, 4), @(56, 4), @(25, 4), @(33, 4), @(6, 5))
foreach ($n in $niches) { $g[$n[1], $n[0]] = 'N' }
# Decorative gate in the hall's north wall (2 cells wide, face rows r-2 and r-1)
Rect 37 16 38 17 'G'
# Water pool in R3 against the north, east and south walls, bordered by a raised platform strip.
Rect 55 22 59 35 'W'
Rect 53 22 54 35 'P'

function C($x, $y) { if ($x -lt 0 -or $y -lt 0 -or $x -ge $W -or $y -ge $H) { return '#' }; return $g[$y, $x] }
# Open = counts as open floor when choosing wall tiles (doors count as wall; water and the
# platform strip count as open).
function IsOpen($x, $y) { $c = C $x $y; return ($c -eq '.' -or $c -eq 'N' -or $c -eq 'W' -or $c -eq 'P') }
function FaceK($x, $y) {
    if (IsOpen $x $y) { return 0 }
    for ($k = 1; $k -le 3; $k++) { if (IsOpen $x ($y + $k)) { return $k } }
    return 0
}

$tops = New-Object 'char[,]' $H, $W; $faces = New-Object 'char[,]' $H, $W; $arch = New-Object 'char[,]' $H, $W
for ($y = 0; $y -lt $H; $y++) { for ($x = 0; $x -lt $W; $x++) { $tops[$y, $x] = ' '; $faces[$y, $x] = ' '; $arch[$y, $x] = ' ' } }
$problems = New-Object System.Collections.Generic.List[string]

for ($y = 0; $y -lt $H; $y++) {
    for ($x = 0; $x -lt $W; $x++) {
        $c = C $x $y
        if ($c -in @('.', 'N', 'D', 'W', 'P')) { continue }
        $k = FaceK $x $y
        $oN = IsOpen $x ($y - 1); $oW = IsOpen ($x - 1) $y; $oE = IsOpen ($x + 1) $y
        if ($k -gt 0) {
            # Brick front. Check the wall is thick enough (no floor directly above the face top).
            if ($k -eq 3 -and $oN) { $problems.Add("face top with floor above at $x,$y") }
            if ($oW -and $oE) { $problems.Add("1-wide face at $x,$y") }
            $row = @{3 = 0; 2 = 1; 1 = 2 }[$k]
            if ($oW) { $faces[$y, $x] = 'DEF'[$row] } elseif ($oE) { $faces[$y, $x] = 'GHI'[$row] } else { $faces[$y, $x] = 'ABC'[$row] }
            continue
        }
        if ($oW -and $oE) { $problems.Add("1-wide wall at $x,$y") }
        $kW = FaceK ($x - 1) $y; $kE = FaceK ($x + 1) $y
        if ($oN -and $oW) { $t = 'c' } elseif ($oN -and $oE) { $t = 'd' } elseif ($oN) { $t = 'b' }
        elseif ($oW) { $t = 'e' } elseif ($oE) { $t = 'f' }
        elseif ($kE -gt 0 -and (C ($x + 1) $y) -ne 'D') { $t = @{3 = 'g'; 2 = 'h'; 1 = 'i' }[$kE] }
        elseif ($kW -gt 0 -and (C ($x - 1) $y) -ne 'D') { $t = @{3 = 'j'; 2 = 'k'; 1 = 'l' }[$kW] }
        elseif (IsOpen ($x + 1) ($y - 1)) { $t = 'm' }
        elseif (IsOpen ($x - 1) ($y - 1)) { $t = 'n' }
        else { $t = 'a' }
        $tops[$y, $x] = $t
    }
}

# Doors: rows r-4..r-1 of two columns. Arch on WallFaces, the wall top above it on ArchTops.
foreach ($key in $doorStyle.Keys) {
    $p = $key.Split(','); $dx = [int]$p[0]; $dy = [int]$p[1]   # top-left door cell (row r-4)
    $style = $doorStyle[$key]
    for ($i = 0; $i -lt 2; $i++) {
        $x = $dx + $i
        $arch[$dy, $x] = $(if (IsOpen $x ($dy - 1)) { 'b' } else { 'a' })
        $arch[($dy + 1), $x] = 'A'
        if ($style -eq 'o') { $faces[($dy + 2), $x] = 'JK'[$i]; $faces[($dy + 3), $x] = 'LM'[$i] }
        else { $faces[($dy + 2), $x] = 'OP'[$i]; $faces[($dy + 3), $x] = 'QR'[$i] }
        $tops[$dy, $x] = ' '; $tops[($dy + 1), $x] = ' '
    }
}
# Niches: columns x-1..x+1, rows r-4..r-1 from the recess block 9..11:1..4.
foreach ($n in $niches) {
    $nx = $n[0]; $r1 = $n[1]
    # Row r-4 (wall top with the recess's back-face top) on WallTops.
    $tops[($r1 - 3), ($nx - 1)] = 'o'; $tops[($r1 - 3), $nx] = 'p'; $tops[($r1 - 3), ($nx + 1)] = 'q'
    foreach ($dx in -1..1) { $faces[($r1 - 3), ($nx + $dx)] = ' ' }
    # Rows r-3..r-1 on WallFaces; (nx, r-1) is the walkable recess floor (10:4 is empty art).
    $faces[($r1 - 2), ($nx - 1)] = 'S'; $faces[($r1 - 1), ($nx - 1)] = 'T'; $faces[$r1, ($nx - 1)] = 'U'
    $faces[($r1 - 2), $nx] = 'V'; $faces[($r1 - 1), $nx] = 'W'; $faces[$r1, $nx] = ' '
    $faces[($r1 - 2), ($nx + 1)] = 'X'; $faces[($r1 - 1), ($nx + 1)] = 'Y'; $faces[$r1, ($nx + 1)] = 'Z'
    foreach ($dx in -1..1) { foreach ($dy in 0..2) { $tops[($r1 - $dy), ($nx + $dx)] = ' ' } }
    foreach ($dx in -1..1) { if ((C ($nx + $dx) ($r1 - 4)) -ne '#' -or (IsOpen ($nx + $dx) ($r1 - 5))) { $problems.Add("niche at $nx,$r1 has no solid wall above") } }
}
# Gate: G cells are face rows r-2 / r-1.
$faces[16, 37] = '1'; $faces[16, 38] = '2'; $faces[17, 37] = '3'; $faces[17, 38] = '4'

function Rows($a) { for ($y = 0; $y -lt $H; $y++) { -join (0..($W - 1) | ForEach-Object { $a[$y, $_] }) } }
$layout = for ($y = 0; $y -lt $H; $y++) { -join (0..($W - 1) | ForEach-Object { $g[$y, $_] }) }
$rng = New-Object System.Random 4242
# ---- Floor layer: base floor under walkable cells grown by one (never under water),
# random cracked-brick variants on walkable cells, then platforms, stairs and the stairwell.
$fl = New-Object 'char[,]' $H, $W
for ($y = 0; $y -lt $H; $y++) { for ($x = 0; $x -lt $W; $x++) {
    $fl[$y, $x] = ' '
    if ((C $x $y) -eq 'W') { continue }
    $hit = $false
    for ($dy = -1; $dy -le 1; $dy++) { for ($dx = -1; $dx -le 1; $dx++) { if ((C ($x + $dx) ($y + $dy)) -in @('.', 'N', 'D', 'P')) { $hit = $true } } }
    if ($hit) { $fl[$y, $x] = 'f' }
    if ((C $x $y) -eq '.' -and $rng.NextDouble() -lt 0.07) { $fl[$y, $x] = '1234'[$rng.Next(4)] }
} }
function Put($a, $x, $y, $ch) { $a[$y, $x] = $ch }
# R4 raised platform x53..59, y5..10 with stairs at x56-57 and a stairwell (pit) on top.
for ($y = 5; $y -le 10; $y++) { for ($x = 53; $x -le 59; $x++) {
    $col = $(if ($x -eq 53) { 0 } elseif ($x -eq 59) { 2 } else { 1 })
    $row = $(if ($y -eq 5) { 0 } elseif ($y -le 8) { 1 } elseif ($y -eq 9) { 2 } else { 3 })
    Put $fl $x $y ('ABC', 'DEF', 'GHI', 'JKL')[$row][$col]
} }
Put $fl 56 9 'M'; Put $fl 57 9 'N'; Put $fl 56 10 'O'; Put $fl 57 10 'Q'
$pit = @('abc', 'deg', 'hij'); for ($i = 0; $i -lt 3; $i++) { for ($k = 0; $k -lt 3; $k++) { Put $fl (54 + $k) (6 + $i) $pit[$i][$k] } }
# R3 platform strip x53..54, y22..35 bordering the pool.
for ($y = 22; $y -le 35; $y++) {
    $row = $(if ($y -eq 22) { 0 } elseif ($y -le 33) { 1 } elseif ($y -eq 34) { 2 } else { 3 })
    Put $fl 53 $y ('ADGJ'[$row]); Put $fl 54 $y ('CFIL'[$row])
}
# ---- Water layer: pool cells, the first row under the north wall shows submerged bricks;
# grown by one under neighbouring walls and platform edges.
$wa = New-Object 'char[,]' $H, $W
for ($y = 0; $y -lt $H; $y++) { for ($x = 0; $x -lt $W; $x++) {
    $wa[$y, $x] = ' '
    $near = $false
    for ($dy = -1; $dy -le 1; $dy++) { for ($dx = -1; $dx -le 1; $dx++) { if ((C ($x + $dx) ($y + $dy)) -eq 'W') { $near = $true } } }
    if (-not $near) { continue }
    if ((C $x $y) -eq 'W' -and (C $x ($y - 1)) -ne 'W') { $wa[$y, $x] = 'w' }
    elseif ((C $x $y) -eq 'W' -and $rng.NextDouble() -lt 0.18) { $wa[$y, $x] = '7890'[$rng.Next(4)] }
    else { $wa[$y, $x] = 'w' }
} }
# ---- Shade (terrain regions): two rows under every brick front, skipping platforms and water.
$shade = New-Object System.Collections.Generic.List[object]
$skip = { param($x, $y) ($x -ge 53 -and $x -le 59 -and $y -ge 5 -and $y -le 10) }
for ($y = 1; $y -lt $H; $y++) {
    $runStart = -1
    for ($x = 0; $x -le $W; $x++) {
        $ok = $false
        if ($x -lt $W) {
            $c = C $x $y
            $ok = ($c -eq '.') -and ((FaceK $x ($y - 1)) -eq 1) -and -not (& $skip $x $y)
        }
        if ($ok -and $runStart -lt 0) { $runStart = $x }
        if (-not $ok -and $runStart -ge 0) {
            $len = $x - $runStart
            # Start one row up, under the brick front, so the visible shadow touches the wall.
            $h2 = $(if ((C $runStart ($y + 1)) -eq '.') { 3 } else { 2 })
            $shade.Add(@{ x = $runStart; y = $y - 1; width = $len; height = $h2 }); $runStart = -1
        }
    }
}
# A few loose patches like in the reference.
foreach ($p in @(@(5, 40, 3, 2), @(24, 30, 3, 2), @(34, 24, 2, 3), @(47, 31, 3, 2), @(12, 12, 2, 2), @(30, 9, 3, 2), @(48, 43, 2, 2))) {
    $shade.Add(@{ x = $p[0]; y = $p[1]; width = $p[2]; height = $p[3] })
}
# ---- Wall cracks on middle brick rows (WallFacesUpper 'B' cells) away from doors, niches and the gate.
$cracks = New-Object 'char[,]' $H, $W
for ($y = 0; $y -lt $H; $y++) { for ($x = 0; $x -lt $W; $x++) {
    $cracks[$y, $x] = ' '
    if ([string]$faces[$y, $x] -ne 'B') { continue }
    $nearSpecial = $false
    foreach ($dx in -2..2) { if ([string]$faces[$y, ($x + $dx)] -cmatch '[JKTWY12]') { $nearSpecial = $true } }
    if (-not $nearSpecial -and $rng.NextDouble() -lt 0.22) { $cracks[$y, $x] = 'abcd'[$rng.Next(4)] }
} }
# ---- Cracked platform frame pieces (FloorDecoration).
$deco = New-Object 'char[,]' $H, $W
for ($y = 0; $y -lt $H; $y++) { for ($x = 0; $x -lt $W; $x++) { $deco[$y, $x] = ' ' } }
Put $deco 53 7 'l'; Put $deco 57 5 't'; Put $deco 59 7 'r'; Put $deco 53 26 'l'; Put $deco 54 30 'r'; Put $deco 53 31 'm'
$layout | Set-Content -Encoding utf8 "$out\layout.txt"
# Split the brick fronts by row: face top rows (k=3) join WallTops, middle rows (k=2)
# go to WallFacesUpper, bottom rows (k=1) stay on WallFaces.
$upper = New-Object 'char[,]' $H, $W
for ($y = 0; $y -lt $H; $y++) { for ($x = 0; $x -lt $W; $x++) {
    $upper[$y, $x] = ' '; $ch = [string]$faces[$y, $x]
    if ('ADGSVX'.Contains($ch) -and $ch -ne ' ') { $tops[$y, $x] = $faces[$y, $x]; $faces[$y, $x] = ' ' }
    elseif ('BEHTWYJKOP12'.Contains($ch) -and $ch -ne ' ') { $upper[$y, $x] = $faces[$y, $x]; $faces[$y, $x] = ' ' }
} }
# ---- Write every layer map (with its legend) to user://floor_maps.
function Legend([string]$spec) { $h = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal); foreach ($e in $spec.Split(' ')) { $p = $e.Split('='); $xy = $p[1].Split(','); $h[$p[0]] = @([int]$xy[0], [int]$xy[1]) }; return ,$h }
function Save($name, $arr, $legend) {
    $rows = @(Rows $arr)
    $miss = (($rows -join '').ToCharArray() | Where-Object { $_ -ne ' ' } | Sort-Object -Unique | Where-Object { -not $legend.ContainsKey([string]$_) })
    if ($miss) { $problems.Add("$name legend misses: $($miss -join ',')") }
    $o = [ordered]@{ origin = @{ x = 0; y = 0 }; legend = $legend; map = $rows }
    [IO.File]::WriteAllText("$out\$name.json", ($o | ConvertTo-Json -Depth 4 -Compress), (New-Object Text.UTF8Encoding($false)))
}
Save 'walltops' $tops (Legend 'a=2,2 b=2,1 c=1,1 d=3,1 e=1,2 f=3,2 g=5,1 h=5,2 i=5,3 j=7,1 k=7,2 l=7,3 m=5,4 n=7,4 o=9,1 p=10,1 q=11,1 A=2,3 D=1,3 G=3,3 S=9,2 V=10,2 X=11,2')
Save 'wallfacesupper' $upper (Legend 'B=2,4 E=1,4 H=3,4 T=9,3 W=10,3 Y=11,3 J=4,24 K=5,24 1=14,26 2=15,26')
Save 'wallfaces' $faces (Legend 'C=2,5 F=1,5 I=3,5 U=9,4 Z=11,4 L=4,25 M=5,25 3=14,27 4=15,27')
Save 'archtops' $arch (Legend 'A=2,3 a=2,2 b=2,1')
Save 'floor' $fl (Legend 'f=2,8 1=7,13 2=8,13 3=7,14 4=8,14 A=1,7 B=2,7 C=3,7 D=1,8 E=2,8 F=3,8 G=1,9 H=2,9 I=3,9 J=1,10 K=2,10 L=3,10 M=10,10 N=11,10 O=10,11 Q=11,11 a=5,7 b=6,7 c=7,7 d=5,8 e=6,8 g=7,8 h=5,9 i=6,9 j=7,9')
Save 'water' $wa (Legend 'w=11,30 r=2,30 7=7,30 8=8,30 9=9,30 0=10,30')
Save 'wallcracks' $cracks (Legend 'a=0,0 b=1,0 c=2,0 d=3,0')
Save 'floordeco' $deco (Legend 'l=1,1 r=5,1 t=2,0 m=2,2')
[IO.File]::WriteAllText("$out\shade_regions.json", ($shade | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding($false)))
@{ layout = @($layout); problems = @($problems) } | ConvertTo-Json -Depth 3 | Set-Content -Encoding utf8 "$out\walls.json"
"problems: $($problems.Count)"; $problems
"shade regions: $($shade.Count)"
"--- floor"; Rows $fl
"--- water"; Rows $wa
"--- cracks"; Rows $cracks
