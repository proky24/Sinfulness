# NewFloor1 prop plan checker (PRD 5, Phase 2).
# Run: powershell -ExecutionPolicy Bypass -File Tests\Tools\newfloor1_props_check.ps1 [-Image <png>]
# Reads the plan Tests/Tools/newfloor1_props.json (the single source of truth, also the input of
# the sinprops_place MCP tool), the layer maps in user://floor_maps (run newfloor1_maps.ps1
# first) and the variant textures, and reports:
#   - props whose footprint leaves the floor of their room, or whose sprite touches a keep-clear
#     zone (doors, niches, entries, corridors, gate, R4 platform/stairs, pool strip, test start)
#     or a wall top (z 1, it would hide the sprite);
#   - overlapping footprints, and gaps between 4 and 14 px (footprint to footprint or to a wall);
#   - reachability: flood fill of the player centre (radius 6.5) from the R1 start, with and
#     without props; lost areas bigger than 2 cells are problems, smaller ones are closed nooks;
#   - density per room, gold and shield counts, repeated clusters in a room, shield wall rules.
# It prints "problems: N". -Image renders the top-down plan at 2x.
# Geometry matches prop.gd: origin = bottom of the opaque pixels, centred on them; footprint
# opaque width - 3 by opaque height / 4 (5..8), ending at the origin.
param([string]$Image = '')
Add-Type -AssemblyName System.Drawing
$root = Split-Path (Split-Path $PSScriptRoot)
$maps = "$env:APPDATA\Godot\app_userdata\Sinfulness\floor_maps"
$plan = Get-Content (Join-Path $PSScriptRoot 'newfloor1_props.json') -Raw | ConvertFrom-Json
$texDir = Join-Path $root 'Entities\GeneralNodes\Props\Textures'
$TS = 16; $MW = 64; $MH = 48; $RADIUS = 6.5; $SEAM = 4; $GAP = 14
$problems = New-Object System.Collections.Generic.List[string]
function Problem([string]$s) { $script:problems.Add($s) }

# ---- Layout and layer maps ----
$layout = @(Get-Content "$maps\layout.txt" | ForEach-Object { $_.TrimStart([char]0xFEFF) })
# Legends have keys that differ only in case ('a' / 'A'), so parse with the case-sensitive serializer.
Add-Type -AssemblyName System.Web.Extensions
$json = New-Object System.Web.Script.Serialization.JavaScriptSerializer
function Read-Map([string]$name) { $json.DeserializeObject((Get-Content "$maps\$name.json" -Raw)) }
function Map-Char($m, [int]$cx, [int]$cy) { $rows = $m['map']; if ($cy -lt 0 -or $cy -ge $rows.Count) { return ' ' }; $row = $rows[$cy]; if ($cx -lt 0 -or $cx -ge $row.Length) { return ' ' }; return $row[$cx] }
$wallTops = Read-Map 'walltops'; $archTops = Read-Map 'archtops'
$faces = Read-Map 'wallfaces'; $facesUp = Read-Map 'wallfacesupper'; $cracks = Read-Map 'wallcracks'
function Legend-Is($m, [char]$c, [int]$ax, [int]$ay) { $leg = $m['legend']; if (-not $leg.ContainsKey([string]$c)) { return $false }; $v = $leg[[string]$c]; return ($v[0] -eq $ax -and $v[1] -eq $ay) }

$rooms = [ordered]@{
	R1 = @(@(4, 34, 15, 42), @(12, 34, 15, 37)); R2 = @(@(20, 18, 41, 33), @(20, 18, 24, 21), @(37, 30, 41, 33))
	R3 = @(, @(46, 22, 59, 35)); R4 = @(, @(46, 5, 59, 14)); R5 = @(@(4, 6, 14, 15), @(11, 6, 14, 9))
	R6 = @(, @(22, 5, 36, 11)); R7 = @(@(46, 40, 57, 45), @(54, 40, 57, 42)); R8 = @(, @(26, 39, 33, 44))
}
$targets = @{ R1 = @(6, 9); R2 = @(14, 20); R3 = @(8, 12); R4 = @(6, 9); R5 = @(8, 12); R6 = @(6, 9); R7 = @(8, 12); R8 = @(5, 8) }
$keepRects = @(
	@('door R6-R2', 27, 18, 30, 19), @('door R6-R2', 27, 10, 30, 11), @('door R2-R8', 28, 32, 31, 33), @('door R2-R8', 28, 39, 31, 40),
	@('door R3-R7', 49, 34, 52, 35), @('door R3-R7', 49, 40, 52, 41), @('door R4-R3', 50, 22, 53, 23), @('door R4-R3', 50, 13, 53, 14),
	@('door R5-R1', 7, 34, 10, 35), @('door R5-R1', 7, 14, 10, 15),
	@('entry R1 east', 14, 37, 15, 41), @('entry R2 south', 20, 31, 24, 33), @('entry R2 east', 40, 25, 41, 29), @('entry R3 west', 46, 25, 47, 29),
	@('entry R6 east', 35, 7, 36, 11), @('entry R4 west', 46, 7, 47, 11), @('gate', 36, 18, 39, 18),
	@('R4 platform', 53, 5, 59, 10), @('R4 stairs', 55, 11, 58, 12), @('test start', 7, 37, 9, 39)
)
$walk = New-Object 'bool[,]' $MW, $MH; $roomOf = New-Object 'string[,]' $MW, $MH; $keep = New-Object 'string[,]' $MW, $MH
for ($cy = 0; $cy -lt $MH; $cy++) { for ($cx = 0; $cx -lt $MW; $cx++) {
	$ch = $layout[$cy][$cx]
	$walk[$cx, $cy] = ($ch -eq '.' -or $ch -eq 'D' -or $ch -eq 'N') -and -not ($cx -ge 54 -and $cx -le 56 -and $cy -ge 6 -and $cy -le 8)
	if ($ch -eq 'P') { $keep[$cx, $cy] = 'pool strip' }
	if (-not $walk[$cx, $cy]) { continue }
	foreach ($rn in $rooms.Keys) { $rr = $rooms[$rn]; $a = $rr[0]
		if ($cx -ge $a[0] -and $cx -le $a[2] -and $cy -ge $a[1] -and $cy -le $a[3]) {
			$inNotch = $false; for ($k = 1; $k -lt $rr.Count; $k++) { $b = $rr[$k]; if ($cx -ge $b[0] -and $cx -le $b[2] -and $cy -ge $b[1] -and $cy -le $b[3]) { $inNotch = $true } }
			if (-not $inNotch) { $roomOf[$cx, $cy] = $rn } } }
	if ($null -eq $roomOf[$cx, $cy]) { $keep[$cx, $cy] = $(if ($ch -eq 'N') { 'niche' } elseif ($ch -eq 'D') { 'door' } else { 'corridor' }) }
	if ($ch -eq 'N') { for ($dx = -1; $dx -le 1; $dx++) { if ($null -eq $keep[($cx + $dx), ($cy + 1)]) { $keep[($cx + $dx), ($cy + 1)] = 'niche light' } } }
} }
foreach ($kr in $keepRects) { for ($cy = $kr[2]; $cy -le $kr[4]; $cy++) { for ($cx = $kr[1]; $cx -le $kr[3]; $cx++) { if ($null -eq $keep[$cx, $cy]) { $keep[$cx, $cy] = $kr[0] } } } }

# ---- Variant geometry (same rules as prop.gd) ----
$atlas = New-Object System.Drawing.Bitmap (Join-Path $root 'Assets\Dungeon TileSet\Objects.png')
$geo = @{}
foreach ($f in Get-ChildItem "$texDir\*.tres") {
	$m = [regex]::Match((Get-Content $f.FullName -Raw), 'region = Rect2\((\d+), (\d+), (\d+), (\d+)\)')
	$rx = [int]$m.Groups[1].Value; $ry = [int]$m.Groups[2].Value; $rw = [int]$m.Groups[3].Value; $rh = [int]$m.Groups[4].Value
	$x0 = 999; $x1 = -1; $y0 = 999; $y1 = -1
	for ($j = 0; $j -lt $rh; $j++) { for ($i = 0; $i -lt $rw; $i++) { if ($atlas.GetPixel($rx + $i, $ry + $j).A -eq 255) {
		if ($i -lt $x0) { $x0 = $i }; if ($i -gt $x1) { $x1 = $i }; if ($j -lt $y0) { $y0 = $j }; if ($j -gt $y1) { $y1 = $j } } } }
	$ow = $x1 - $x0 + 1; $oh = $y1 - $y0 + 1
	$geo[$f.BaseName] = @{ rx = $rx; ry = $ry; rw = $rw; rh = $rh; ox = $x0; oy = $y0; ow = $ow; oh = $oh; ob = $y1 + 1
		ccx = $x0 + [math]::Floor($ow / 2); fw = [math]::Max($ow - 3, 4); fh = [math]::Min([math]::Max([math]::Floor($oh / 4 + 0.5), 5), 8) }
}

# ---- Props ----
$props = New-Object System.Collections.Generic.List[object]
foreach ($grp in $plan.groups) { foreach ($p in $grp.props) {
	$g = $geo[$p.variant]
	if ($null -eq $g) { Problem "$($grp.name): unknown variant $($p.variant)"; continue }
	$lift = $(if ($null -ne $p.lift) { [int]$p.lift } else { 0 })
	$flat = [bool]$p.flat; $solid = $(if ($null -ne $p.solid) { [bool]$p.solid } else { $true }) -and -not $flat
	$sx = $p.x - $g.ccx; $sy = $p.y - $g.ob - $lift
	$fcx = $p.x + $g.ox + $g.ow / 2.0 - $g.ccx
	$props.Add([pscustomobject]@{ group = $grp.name; variant = $p.variant; x = [double]$p.x; y = [double]$p.y; solid = $solid; flat = $flat; lift = $lift
		label = "$($grp.name)/$($p.variant)@($($p.x),$($p.y))"; sx = $sx; sy = $sy; g = $g
		ox0 = $sx + $g.ox; oy0 = $sy + $g.oy; ox1 = $sx + $g.ox + $g.ow; oy1 = $sy + $g.oy + $g.oh
		fx0 = $fcx - $g.fw / 2.0; fx1 = $fcx + $g.fw / 2.0; fy0 = $p.y - $g.fh; fy1 = [double]$p.y })
} }
function Cells-Of([double]$x0, [double]$y0, [double]$x1, [double]$y1) {
	$r = @(); for ($cy = [math]::Floor($y0 / $TS); $cy -le [math]::Floor(($y1 - 0.001) / $TS); $cy++) { for ($cx = [math]::Floor($x0 / $TS); $cx -le [math]::Floor(($x1 - 0.001) / $TS); $cx++) { $r += , @([int]$cx, [int]$cy) } }; return , $r }
function Rect-Dist([double]$ax0, [double]$ay0, [double]$ax1, [double]$ay1, [double]$bx0, [double]$by0, [double]$bx1, [double]$by1) {
	$dx = [math]::Max(0, [math]::Max($bx0 - $ax1, $ax0 - $bx1)); $dy = [math]::Max(0, [math]::Max($by0 - $ay1, $ay0 - $by1)); return [math]::Sqrt($dx * $dx + $dy * $dy) }
# A gap between two rects (footprints or a wall cell) is filled when a third footprint touches the
# space between them, so the player never sees it as a passage.
function Gap-Filled($p, $q) {
	$gx0 = [math]::Min($p.fx1, $q.fx1); $gx1 = [math]::Max($p.fx0, $q.fx0); if ($gx0 -gt $gx1) { $t = $gx0; $gx0 = $gx1; $gx1 = $t }
	$gy0 = [math]::Min($p.fy1, $q.fy1); $gy1 = [math]::Max($p.fy0, $q.fy0); if ($gy0 -gt $gy1) { $t = $gy0; $gy0 = $gy1; $gy1 = $t }
	foreach ($o in $props) { if ($o.solid -and -not [object]::ReferenceEquals($o, $p) -and -not [object]::ReferenceEquals($o, $q) -and
		$o.fx0 -le $gx1 + 1 -and $o.fx1 -ge $gx0 - 1 -and $o.fy0 -le $gy1 + 1 -and $o.fy1 -ge $gy0 - 1) { return $true } }
	return $false
}

foreach ($p in $props) {
	if ($p.group -eq 'Shields') { continue }
	$room = $p.group -replace '_Props$', ''
	# Footprint (or the whole opaque rect for flat props) on the floor of its own room.
	if ($p.solid) { $base = Cells-Of $p.fx0 $p.fy0 $p.fx1 $p.fy1 } else { $base = Cells-Of $p.ox0 ($p.oy1 - 4) $p.ox1 $p.oy1 }
	foreach ($c in $base) { if ($roomOf[$c[0], $c[1]] -ne $room) { Problem "$($p.label): base on cell ($($c[0]),$($c[1])) that is not $room floor"; break } }
	foreach ($c in (Cells-Of $p.ox0 $p.oy0 $p.ox1 $p.oy1)) {
		$cx = $c[0]; $cy = $c[1]
		if ($null -ne $keep[$cx, $cy] -and $walk[$cx, $cy]) { Problem "$($p.label): sprite on keep-clear cell ($cx,$cy) [$($keep[$cx, $cy])]"; break }
		if ((Map-Char $wallTops $cx $cy) -ne ' ' -or (Map-Char $archTops $cx $cy) -ne ' ') { Problem "$($p.label): sprite under a wall top at ($cx,$cy)"; break } }
	if ($p.solid) {
		$cx0 = [math]::Floor($p.fx0 / $TS) - 1; $cy0 = [math]::Floor($p.fy0 / $TS) - 1
		$worst = 99
		for ($cy = $cy0; $cy -le $cy0 + 2; $cy++) { for ($cx = $cx0; $cx -le $cx0 + 3; $cx++) { if (-not $walk[$cx, $cy]) {
			$wc = [pscustomobject]@{ fx0 = [double]($cx * $TS); fy0 = [double]($cy * $TS); fx1 = [double](($cx + 1) * $TS); fy1 = [double](($cy + 1) * $TS) }
			$d = Rect-Dist $p.fx0 $p.fy0 $p.fx1 $p.fy1 $wc.fx0 $wc.fy0 $wc.fx1 $wc.fy1
			if ($d -lt $worst -and -not ($d -gt $SEAM -and (Gap-Filled $p $wc))) { $worst = $d } } } }
		if ($worst -gt $SEAM -and $worst -lt $GAP) { Problem ("$($p.label): {0:N1} px gap to a wall (allowed <= $SEAM or >= $GAP)" -f $worst) }
	}
}
for ($a = 0; $a -lt $props.Count; $a++) { for ($b = $a + 1; $b -lt $props.Count; $b++) {
	$p = $props[$a]; $q = $props[$b]
	if ($p.solid -and $q.solid) {
		$ovx = [math]::Min($p.fx1, $q.fx1) - [math]::Max($p.fx0, $q.fx0); $ovy = [math]::Min($p.fy1, $q.fy1) - [math]::Max($p.fy0, $q.fy0)
		if ($ovx -gt 0 -and $ovy -gt 0) { Problem "$($p.label) and $($q.label): footprints overlap" }
		else { $d = Rect-Dist $p.fx0 $p.fy0 $p.fx1 $p.fy1 $q.fx0 $q.fy0 $q.fx1 $q.fy1
			if ($d -gt $SEAM -and $d -lt $GAP -and -not (Gap-Filled $p $q)) { Problem ("$($p.label) and $($q.label): {0:N1} px gap (allowed <= $SEAM or >= $GAP)" -f $d) } } }
	elseif ($p.flat -xor $q.flat) { $fl = $(if ($p.flat) { $p } else { $q }); $so = $(if ($p.flat) { $q } else { $p })
		if ($so.solid -and [math]::Min($fl.ox1, $so.fx1) -gt [math]::Max($fl.ox0, $so.fx0) -and [math]::Min($fl.oy1, $so.fy1) -gt [math]::Max($fl.oy0, $so.fy0)) { Problem "$($fl.label) lies under $($so.label)'s footprint" } }
	if (($p.group -eq 'Shields') -xor ($q.group -eq 'Shields')) { $sh = $(if ($p.group -eq 'Shields') { $p } else { $q }); $ot = $(if ($p.group -eq 'Shields') { $q } else { $p })
		if ([math]::Min($sh.ox1, $ot.ox1) -gt [math]::Max($sh.ox0, $ot.ox0) -and [math]::Min($sh.oy1, $ot.oy1) -gt [math]::Max($sh.oy0, $ot.oy0)) { Problem "$($ot.label) covers $($sh.label)" } }
} }

# ---- Shields ----
foreach ($p in ($props | Where-Object { $_.group -eq 'Shields' })) {
	$cx = [int][math]::Floor($p.x / $TS); $rf = ($p.y - 1) / $TS; $r = [int][math]::Floor($rf)
	if ($p.x -ne $cx * $TS + 8 -or $rf -ne $r) { Problem "$($p.label): not at a cell centre x and y = r*16 + 1"; continue }
	if ($p.lift -ne 18 -or $p.solid) { Problem "$($p.label): needs lift 18 and solid false" }
	if (-not $walk[$cx, $r] -or $null -eq $roomOf[$cx, $r] -or $walk[$cx, ($r - 1)] -or $walk[$cx, ($r - 2)] -or $walk[$cx, ($r - 3)]) { Problem "$($p.label): not on a wall north of a room"; continue }
	if (-not (Legend-Is $faces (Map-Char $faces $cx ($r - 1)) 2 5) -or -not (Legend-Is $facesUp (Map-Char $facesUp $cx ($r - 2)) 2 4)) { Problem "$($p.label): not on plain brick front (end piece, arch or niche)" }
	if ((Map-Char $cracks $cx ($r - 2)) -ne ' ') { Problem "$($p.label): on a cracked brick" }
	for ($yy = $r - 5; $yy -le $r; $yy++) { for ($xx = $cx - 2; $xx -le $cx + 2; $xx++) { $ch = $layout[$yy][$xx]
		if ($ch -eq 'D' -or $ch -eq 'N' -or $ch -eq 'G') { Problem "$($p.label): within 2 tiles of '$ch' at ($xx,$yy)"; $yy = 99; break } } }
}

# ---- Reachability (flood fill of the player centre) ----
Add-Type -TypeDefinition @'
public static class PropReach {
	// Cells (mw x mh, ts px each) reached by the player centre from (sx, sy). Blocked: non-walkable
	// cells and the rects (x0, y0, x1, y1 per prop), grown by radius.
	public static bool[] ReachCells(bool[] walk, int mw, int mh, int ts, double[] rects, double radius, int sx, int sy) {
		int w = mw * ts, h = mh * ts;
		bool[] blocked = new bool[w * h];
		for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) blocked[y * w + x] = !walk[(y / ts) * mw + x / ts];
		for (int k = 0; k + 3 < rects.Length; k += 4)
			for (int y = (int)System.Math.Floor(rects[k + 1]); y < (int)System.Math.Ceiling(rects[k + 3]); y++)
				for (int x = (int)System.Math.Floor(rects[k]); x < (int)System.Math.Ceiling(rects[k + 2]); x++) blocked[y * w + x] = true;
		int r = (int)System.Math.Ceiling(radius); double r2 = radius * radius;
		bool[] near = new bool[w * h];
		for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
			if (!blocked[y * w + x]) continue;
			bool edge = x == 0 || y == 0 || x == w - 1 || y == h - 1 || !blocked[y * w + x - 1] || !blocked[y * w + x + 1] || !blocked[(y - 1) * w + x] || !blocked[(y + 1) * w + x];
			near[y * w + x] = true;
			if (!edge) continue;
			for (int dy = -r; dy <= r; dy++) for (int dx = -r; dx <= r; dx++) {
				// distance from a pixel centre to the blocked pixel square
				double ex = System.Math.Max(0, System.Math.Abs(dx) - 0.5), ey = System.Math.Max(0, System.Math.Abs(dy) - 0.5);
				if (ex * ex + ey * ey >= r2) continue;
				int nx = x + dx, ny = y + dy; if (nx >= 0 && ny >= 0 && nx < w && ny < h) near[ny * w + nx] = true; } }
		bool[] cells = new bool[mw * mh]; bool[] seen = new bool[w * h];
		var stack = new System.Collections.Generic.Stack<int>(); int s = sy * w + sx;
		if (near[s]) return cells; seen[s] = true; stack.Push(s);
		while (stack.Count > 0) { int i = stack.Pop(); int x = i % w, y = i / w; cells[(y / ts) * mw + x / ts] = true;
			if (x > 0 && !seen[i - 1] && !near[i - 1]) { seen[i - 1] = true; stack.Push(i - 1); }
			if (x < w - 1 && !seen[i + 1] && !near[i + 1]) { seen[i + 1] = true; stack.Push(i + 1); }
			if (y > 0 && !seen[i - w] && !near[i - w]) { seen[i - w] = true; stack.Push(i - w); }
			if (y < h - 1 && !seen[i + w] && !near[i + w]) { seen[i + w] = true; stack.Push(i + w); } }
		return cells; }
}
'@
$walkFlat = New-Object 'bool[]' ($MW * $MH)
for ($cy = 0; $cy -lt $MH; $cy++) { for ($cx = 0; $cx -lt $MW; $cx++) { $walkFlat[$cy * $MW + $cx] = $walk[$cx, $cy] } }
$rects = New-Object System.Collections.Generic.List[double]
foreach ($p in $props) { if ($p.solid) { $rects.Add($p.fx0); $rects.Add($p.fy0); $rects.Add($p.fx1); $rects.Add($p.fy1) } }
$beforeFlat = [PropReach]::ReachCells($walkFlat, $MW, $MH, $TS, (New-Object 'double[]' 0), $RADIUS, 136, 616)
$afterFlat = [PropReach]::ReachCells($walkFlat, $MW, $MH, $TS, $rects.ToArray(), $RADIUS, 136, 616)
$before = New-Object 'bool[,]' $MW, $MH; $after = New-Object 'bool[,]' $MW, $MH
for ($cy = 0; $cy -lt $MH; $cy++) { for ($cx = 0; $cx -lt $MW; $cx++) { $before[$cx, $cy] = $beforeFlat[$cy * $MW + $cx]; $after[$cx, $cy] = $afterFlat[$cy * $MW + $cx] } }
$walkCount = 0; $beforeCount = 0; $lost = New-Object 'bool[,]' $MW, $MH
for ($cy = 0; $cy -lt $MH; $cy++) { for ($cx = 0; $cx -lt $MW; $cx++) { if ($walk[$cx, $cy]) { $walkCount++; if ($before[$cx, $cy]) { $beforeCount++; if (-not $after[$cx, $cy]) { $lost[$cx, $cy] = $true } } } } }
$nooks = @()
for ($cy = 0; $cy -lt $MH; $cy++) { for ($cx = 0; $cx -lt $MW; $cx++) { if ($lost[$cx, $cy]) {
	$comp = @(); $st = New-Object System.Collections.Stack; $st.Push(@($cx, $cy)); $lost[$cx, $cy] = $false
	while ($st.Count) { $c = $st.Pop(); $comp += , $c
		foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) { $nx = $c[0] + $d[0]; $ny = $c[1] + $d[1]; if ($lost[$nx, $ny]) { $lost[$nx, $ny] = $false; $st.Push(@($nx, $ny)) } } }
	$txt = ($comp | ForEach-Object { "($($_[0]),$($_[1]))" }) -join ' '
	if ($comp.Count -le 2) { $nooks += "closed nook: $txt" } else { Problem "unreachable with props: $txt" } } } }

# ---- Density ----
$total = 0; $goldRooms = @{}; $goldCount = 0
foreach ($grp in $plan.groups) {
	$pieces = @($grp.props | Where-Object { -not $_.flat }); $gold = @($grp.props | Where-Object { $_.flat })
	$total += $grp.props.Count; $goldCount += $gold.Count; if ($gold.Count) { $goldRooms[$grp.name] = $gold.Count }
	if ($grp.name -eq 'Shields') { if ($pieces.Count -lt 6 -or $pieces.Count -gt 8) { Problem "Shields: $($pieces.Count), target 6-8" }; "Shields: $($pieces.Count) (target 6-8)"; continue }
	$room = $grp.name -replace '_Props$', ''; $t = $targets[$room]
	"{0}: {1} pieces (target {2}-{3}), {4} gold" -f $grp.name, $pieces.Count, $t[0], $t[1], $gold.Count
	if ($pieces.Count -lt $t[0] -or $pieces.Count -gt $t[1]) { Problem "$($grp.name): $($pieces.Count) pieces, target $($t[0])-$($t[1])" }
	$clusters = @($pieces | Where-Object { $_.variant -like 'cluster_*' } | Group-Object variant | Where-Object { $_.Count -gt 1 })
	foreach ($c in $clusters) { Problem "$($grp.name): cluster $($c.Name) used $($c.Count) times" }
}
if ($goldCount -lt 4 -or $goldCount -gt 8 -or $goldRooms.Count -lt 2 -or $goldRooms.Count -gt 3) { Problem "gold: $goldCount piles in $($goldRooms.Count) rooms, target 4-8 in 2-3 rooms" }
if ($total -lt 65 -or $total -gt 95) { Problem "total $total Prop instances, target 65-95" }
"gold: $goldCount piles in $($goldRooms.Count) rooms; total: $total Prop instances"
"walkable cells: $walkCount, reachable without props: $beforeCount"
$nooks
$problems | ForEach-Object { "PROBLEM: $_" }
"problems: $($problems.Count)"

# ---- Plan image ----
if ($Image -ne '') {
	$PW = $MW * $TS; $PH = $MH * $TS
	$S = 2; $img = New-Object System.Drawing.Bitmap ($PW * $S), ($PH * $S)
	$gr = [System.Drawing.Graphics]::FromImage($img)
	$gr.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor; $gr.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
	$col = @{ wall = [System.Drawing.Color]::FromArgb(255, 46, 44, 60); void = [System.Drawing.Color]::FromArgb(255, 24, 22, 34); floor = [System.Drawing.Color]::FromArgb(255, 132, 146, 172)
		corr = [System.Drawing.Color]::FromArgb(255, 110, 122, 146); water = [System.Drawing.Color]::FromArgb(255, 50, 120, 200); strip = [System.Drawing.Color]::FromArgb(255, 150, 150, 170)
		door = [System.Drawing.Color]::FromArgb(255, 150, 105, 60); niche = [System.Drawing.Color]::FromArgb(255, 230, 190, 60); gate = [System.Drawing.Color]::FromArgb(255, 90, 90, 110) }
	$keepBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(70, 255, 40, 40))
	for ($cy = 0; $cy -lt $MH; $cy++) { for ($cx = 0; $cx -lt $MW; $cx++) {
		$ch = $layout[$cy][$cx]
		$c = switch ($ch) { '.' { if ($null -ne $roomOf[$cx, $cy]) { $col.floor } else { $col.corr } } 'D' { $col.door } 'N' { $col.niche } 'W' { $col.water } 'P' { $col.strip } 'G' { $col.gate } default { if ((Map-Char $wallTops $cx $cy) -ne ' ' -and (Map-Char $faces $cx $cy) -eq ' ' -and (Map-Char $facesUp $cx $cy) -eq ' ') { $col.void } else { $col.wall } } }
		if ($cx -ge 54 -and $cx -le 56 -and $cy -ge 6 -and $cy -le 8) { $c = $col.void }
		$br = New-Object System.Drawing.SolidBrush $c; $gr.FillRectangle($br, $cx * $TS * $S, $cy * $TS * $S, $TS * $S, $TS * $S); $br.Dispose()
		if ($null -ne $keep[$cx, $cy] -and $walk[$cx, $cy]) { $gr.FillRectangle($keepBrush, $cx * $TS * $S, $cy * $TS * $S, $TS * $S, $TS * $S) } } }
	$gridPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(40, 255, 255, 255)), 1
	for ($cx = 0; $cx -le $MW; $cx++) { $gr.DrawLine($gridPen, $cx * $TS * $S, 0, $cx * $TS * $S, $PH * $S) }
	for ($cy = 0; $cy -le $MH; $cy++) { $gr.DrawLine($gridPen, 0, $cy * $TS * $S, $PW * $S, $cy * $TS * $S) }
	$solidPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::Lime), 2; $flatPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::Cyan), 2; $shieldPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::Orange), 2
	foreach ($p in ($props | Sort-Object { if ($_.flat) { -1 } else { $_.y } })) {
		$g = $p.g
		$dst = New-Object System.Drawing.Rectangle ([int]($p.sx * $S)), ([int]($p.sy * $S)), ($g.rw * $S), ($g.rh * $S)
		$gr.DrawImage($atlas, $dst, $g.rx, $g.ry, $g.rw, $g.rh, [System.Drawing.GraphicsUnit]::Pixel)
	}
	foreach ($p in $props) {
		if ($p.group -eq 'Shields') { $gr.DrawRectangle($shieldPen, [float]($p.ox0 * $S), [float]($p.oy0 * $S), [float](($p.ox1 - $p.ox0) * $S), [float](($p.oy1 - $p.oy0) * $S)) }
		elseif ($p.flat) { $gr.DrawRectangle($flatPen, [float]($p.ox0 * $S), [float]($p.oy0 * $S), [float](($p.ox1 - $p.ox0) * $S), [float](($p.oy1 - $p.oy0) * $S)) }
		else { $gr.DrawRectangle($solidPen, [float]($p.fx0 * $S), [float]($p.fy0 * $S), [float](($p.fx1 - $p.fx0) * $S), [float](($p.fy1 - $p.fy0) * $S)) } }
	$font = New-Object System.Drawing.Font 'Consolas', 14, ([System.Drawing.FontStyle]::Bold)
	$labels = @{ R1 = @(4, 39); R2 = @(29, 24); R3 = @(47, 31); R4 = @(46, 12); R5 = @(5, 12); R6 = @(30, 8); R7 = @(47, 43); R8 = @(26, 41) }
	foreach ($rn in $labels.Keys) { $grp = $plan.groups | Where-Object { $_.name -eq "$($rn)_Props" }
		$n = @($grp.props | Where-Object { -not $_.flat }).Count; $gd = @($grp.props | Where-Object { $_.flat }).Count
		$t = "$rn $n" + $(if ($gd) { " +$gd gold" } else { '' })
		$gr.DrawString($t, $font, [System.Drawing.Brushes]::Black, $labels[$rn][0] * $TS * $S + 2, $labels[$rn][1] * $TS * $S + 2)
		$gr.DrawString($t, $font, [System.Drawing.Brushes]::White, $labels[$rn][0] * $TS * $S, $labels[$rn][1] * $TS * $S) }
	$small = New-Object System.Drawing.Font 'Consolas', 12
	$gr.DrawString('green = footprint (solid)   cyan = gold (flat)   orange = shield   red tint = keep clear   brown = door   yellow = niche', $small, [System.Drawing.Brushes]::White, 8, $PH * $S - 26)
	$gr.Dispose(); $img.Save($Image, [System.Drawing.Imaging.ImageFormat]::Png); $img.Dispose()
	"plan image saved to $Image"
}
$atlas.Dispose()
