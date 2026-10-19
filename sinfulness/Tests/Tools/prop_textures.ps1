# Prop variant textures for NewFloor1 (PRD 5, Phase 1).
# Run: powershell -ExecutionPolicy Bypass -File Tests\Tools\prop_textures.ps1 [-Write] [-Preview <png>]
# The region table below is the single source of truth: x, y, w, h in Objects.png pixels, baked
# shadow included. The script checks every region (tight alpha box, no overlap with another
# region, no neighbour pixels inside, no object cut at the edge), prints "problems: N", and
# with -Write saves one AtlasTexture .tres per variant to Entities/GeneralNodes/Props/Textures.
# -Preview renders a labelled sheet: each region at 4x on a checker, a red line + tick at the base
# (bottom of the opaque pixels = the Prop origin) and a full-atlas overview with all regions.
param([switch]$Write, [string]$Preview = '')
Add-Type -AssemblyName System.Drawing
$root = Split-Path (Split-Path $PSScriptRoot)
$png = Join-Path $root 'Assets\Dungeon TileSet\Objects.png'
$texDir = Join-Path $root 'Entities\GeneralNodes\Props\Textures'
$atlasUid = 'uid://dg7gu4eh8wg2t'
$atlasPath = 'res://Assets/Dungeon TileSet/Objects.png'

# name, x, y, w, h. Splits of merged blobs: tall crates end at y 111 (vase cluster / lever start
# at 112); medium crates end at x 111 and barrels start at x 112; shields split at x 111 | 112.
$regions = @(
	@('crate_tall_light', 55, 85, 19, 27), @('crate_small_light', 82, 83, 13, 18), @('crate_medium_light', 96, 80, 16, 23),
	@('crate_tall_dark', 135, 85, 19, 27), @('crate_small_dark', 162, 83, 13, 18), @('crate_medium_dark', 176, 80, 16, 23),
	@('barrel_light', 112, 80, 16, 24), @('barrel_dark', 192, 80, 16, 24),
	@('vase_blue_large', 209, 80, 14, 19), @('vase_blue_medium', 226, 83, 11, 16), @('vase_blue_small', 244, 86, 9, 12),
	@('vase_brown_large', 257, 80, 14, 19), @('vase_brown_medium', 274, 83, 11, 16), @('vase_brown_small', 292, 86, 9, 12),
	@('cluster_vases_3', 23, 112, 21, 24), @('cluster_vases_2_small', 49, 115, 14, 19), @('cluster_vases_2_tall', 64, 112, 16, 24),
	@('cluster_crates_2', 274, 26, 25, 30), @('cluster_crates_3', 306, 21, 28, 36), @('cluster_crates_stack', 344, 16, 19, 27),
	@('cluster_crate_barrel_vases', 336, 48, 29, 32), @('cluster_barrel_crate_vase', 308, 64, 27, 30), @('cluster_barrel_crate', 341, 80, 22, 29),
	@('shield_a', 97, 117, 15, 15), @('shield_b', 112, 112, 15, 15),
	@('gold_pile_double', 177, 113, 15, 13), @('gold_pile_large', 192, 113, 16, 12), @('gold_pile_medium', 209, 114, 14, 10), @('gold_pile_small', 227, 116, 10, 7),
	@('gold_pile_double_big', 215, 23, 19, 17), @('gold_pile_triple', 213, 54, 22, 17)
)

# Excluded objects that touch a variant (PRD 5 §4): not textures, but a blob may continue into them.
$excluded = @(,@('lever', 144, 112, 13, 10))

$bmp = New-Object System.Drawing.Bitmap $png
$AW = $bmp.Width; $AH = $bmp.Height
$alpha = New-Object 'int[,]' $AW, $AH
for ($j = 0; $j -lt $AH; $j++) { for ($i = 0; $i -lt $AW; $i++) { $alpha[$i, $j] = $bmp.GetPixel($i, $j).A } }

# Connected components (8-neighbour, alpha > 0) to tell merged blobs from foreign pixels.
$lab = New-Object 'int[,]' $AW, $AH
$labSize = @{}; $n = 0
for ($j = 0; $j -lt $AH; $j++) { for ($i = 0; $i -lt $AW; $i++) {
	if ($alpha[$i, $j] -gt 0 -and $lab[$i, $j] -eq 0) {
		$n++; $st = New-Object System.Collections.Stack; $st.Push(@($i, $j)); $lab[$i, $j] = $n; $cnt = 0
		while ($st.Count) { $p = $st.Pop(); $cnt++
			for ($dj = -1; $dj -le 1; $dj++) { for ($di = -1; $di -le 1; $di++) { $qi = $p[0] + $di; $qj = $p[1] + $dj
				if ($qi -ge 0 -and $qj -ge 0 -and $qi -lt $AW -and $qj -lt $AH -and $lab[$qi, $qj] -eq 0 -and $alpha[$qi, $qj] -gt 0) { $lab[$qi, $qj] = $n; $st.Push(@($qi, $qj)) } } } }
		$labSize[$n] = $cnt } } }

$problems = 0; $info = @{}
function Note([string]$s) { $script:problems++; "PROBLEM: $s" }
foreach ($r in $regions) {
	$nm = $r[0]; $rx = $r[1]; $ry = $r[2]; $rw = $r[3]; $rh = $r[4]
	$ax0 = 9999; $ay0 = 9999; $ax1 = -1; $ay1 = -1; $ox0 = 9999; $ox1 = -1; $oy1 = -1; $labsIn = @{}
	for ($j = $ry; $j -lt $ry + $rh; $j++) { for ($i = $rx; $i -lt $rx + $rw; $i++) {
		if ($alpha[$i, $j] -gt 0) {
			if ($i -lt $ax0) { $ax0 = $i }; if ($i -gt $ax1) { $ax1 = $i }; if ($j -lt $ay0) { $ay0 = $j }; if ($j -gt $ay1) { $ay1 = $j }
			$l = $lab[$i, $j]; if ($labsIn.ContainsKey($l)) { $labsIn[$l]++ } else { $labsIn[$l] = 1 } }
		if ($alpha[$i, $j] -eq 255) { if ($i -lt $ox0) { $ox0 = $i }; if ($i -gt $ox1) { $ox1 = $i }; if ($j -gt $oy1) { $oy1 = $j } } } }
	if ($ax0 -ne $rx -or $ay0 -ne $ry -or $ax1 -ne $rx + $rw - 1 -or $ay1 -ne $ry + $rh - 1) {
		Note "$nm region not tight: alpha box x $ax0..$ax1 y $ay0..$ay1" }
	# Blobs only partly inside: a planned split (the rest lies in another region) or a cut/neighbour.
	foreach ($l in $labsIn.Keys) { if ($labsIn[$l] -lt $labSize[$l]) {
		$elsewhere = 0
		foreach ($o in ($regions + $excluded)) { if ($o[0] -ne $nm) { for ($j = $o[2]; $j -lt $o[2] + $o[4]; $j++) { for ($i = $o[1]; $i -lt $o[1] + $o[3]; $i++) { if ($lab[$i, $j] -eq $l) { $elsewhere++ } } } } }
		$outside = $labSize[$l] - $labsIn[$l]
		if ($labsIn[$l] -lt 0.25 * $labSize[$l] -and $labsIn[$l] -lt 30) { Note "$nm contains $($labsIn[$l]) px of a neighbour (blob $l)" }
		elseif ($elsewhere -lt $outside) { Note "$nm blob $l continues outside all regions ($($outside - $elsewhere) px): object cut?" }
		else { "split ok: $nm shares blob $l with another region ($($labsIn[$l]) of $($labSize[$l]) px here)" } } }
	$info[$nm] = @{ ox0 = $ox0; ox1 = $ox1; oy1 = $oy1 }
}
for ($a = 0; $a -lt $regions.Count; $a++) { for ($b = $a + 1; $b -lt $regions.Count; $b++) {
	$p = $regions[$a]; $q = $regions[$b]
	if ($p[1] -lt $q[1] + $q[3] -and $q[1] -lt $p[1] + $p[3] -and $p[2] -lt $q[2] + $q[4] -and $q[2] -lt $p[2] + $p[4]) { Note "$($p[0]) overlaps $($q[0])" } } }
"regions: $($regions.Count)"
"problems: $problems"

if ($Write) {
	New-Item -ItemType Directory -Force $texDir | Out-Null
	$utf8 = New-Object System.Text.UTF8Encoding $false
	foreach ($r in $regions) {
		$txt = "[gd_resource type=`"AtlasTexture`" format=3]`n`n" +
			"[ext_resource type=`"Texture2D`" uid=`"$atlasUid`" path=`"$atlasPath`" id=`"1_atlas`"]`n`n" +
			"[resource]`natlas = ExtResource(`"1_atlas`")`nregion = Rect2($($r[1]), $($r[2]), $($r[3]), $($r[4]))`nfilter_clip = true`n"
		[System.IO.File]::WriteAllText((Join-Path $texDir "$($r[0]).tres"), $txt, $utf8)
	}
	"wrote $($regions.Count) textures to $texDir"
}

if ($Preview -ne '') {
	$S = 4; $cellW = 190; $cellH = 190; $cols = 7; $ov = 3
	$rows = [math]::Ceiling($regions.Count / $cols)
	$sheetW = [math]::Max($cols * $cellW, $AW * $ov + 20); $sheetH = $rows * $cellH + $AH * $ov + 50
	$sh = New-Object System.Drawing.Bitmap $sheetW, $sheetH
	$g = [System.Drawing.Graphics]::FromImage($sh)
	$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
	$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
	$g.Clear([System.Drawing.Color]::FromArgb(255, 40, 40, 48))
	$font = New-Object System.Drawing.Font 'Consolas', 8
	$c1 = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 150, 150, 160))
	$c2 = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 120, 120, 130))
	$red = New-Object System.Drawing.Pen ([System.Drawing.Color]::Red), 1
	$yel = New-Object System.Drawing.Pen ([System.Drawing.Color]::Yellow), 1
	for ($k = 0; $k -lt $regions.Count; $k++) {
		$r = $regions[$k]; $cx = ($k % $cols) * $cellW; $cy = [math]::Floor($k / $cols) * $cellH
		$dw = $r[3] * $S; $dh = $r[4] * $S; $dx = $cx + [int](($cellW - $dw) / 2); $dy = $cy + 8 + (140 - $dh)
		for ($j = 0; $j -lt $r[4]; $j++) { for ($i = 0; $i -lt $r[3]; $i++) {
			$g.FillRectangle($(if ((($i + $j) % 2) -eq 0) { $c1 } else { $c2 }), $dx + $i * $S, $dy + $j * $S, $S, $S) } }
		$g.DrawImage($bmp, (New-Object System.Drawing.Rectangle $dx, $dy, $dw, $dh), $r[1], $r[2], $r[3], $r[4], [System.Drawing.GraphicsUnit]::Pixel)
		$inf = $info[$r[0]]
		$by = $dy + ($inf.oy1 + 1 - $r[2]) * $S
		$g.DrawLine($red, $dx - 6, $by, $dx + $dw + 6, $by)
		$ocx = $dx + [math]::Floor(($inf.ox0 + $inf.ox1 + 1) / 2 - $r[1]) * $S
		$g.DrawLine($red, $ocx, $by - 5, $ocx, $by + 5)
		$g.DrawString("$($k + 1). $($r[0])", $font, [System.Drawing.Brushes]::White, $cx + 4, $cy + 152)
		$g.DrawString("($($r[1]), $($r[2]), $($r[3]), $($r[4]))", $font, [System.Drawing.Brushes]::Silver, $cx + 4, $cy + 166)
	}
	$oy = $rows * $cellH + 30
	$g.DrawString("Objects.png at ${ov}x, yellow = variant regions (numbers as above)", $font, [System.Drawing.Brushes]::White, 10, $oy - 18)
	$g.FillRectangle($c2, 10, $oy, $AW * $ov, $AH * $ov)
	$g.DrawImage($bmp, (New-Object System.Drawing.Rectangle 10, $oy, ($AW * $ov), ($AH * $ov)), 0, 0, $AW, $AH, [System.Drawing.GraphicsUnit]::Pixel)
	for ($k = 0; $k -lt $regions.Count; $k++) { $r = $regions[$k]
		$g.DrawRectangle($yel, 10 + $r[1] * $ov, $oy + $r[2] * $ov, $r[3] * $ov - 1, $r[4] * $ov - 1)
		$g.DrawString("$($k + 1)", $font, [System.Drawing.Brushes]::Yellow, 10 + $r[1] * $ov, $oy + $r[2] * $ov - 12) }
	$g.Dispose(); $sh.Save($Preview, [System.Drawing.Imaging.ImageFormat]::Png); $sh.Dispose()
	"preview saved to $Preview"
}
$bmp.Dispose()
