param(
    [string]$Png,
    [string]$Tscn,
    [string]$Out,
    [int]$Scale = 4,
    [switch]$NoCollision
)
Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Image]::FromFile($Png)
$margin = 28
$w = $src.Width * $Scale + $margin
$h = $src.Height * $Scale + $margin
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g.Clear([System.Drawing.Color]::FromArgb(255, 255, 0, 255))
$g.FillRectangle([System.Drawing.Brushes]::White, 0, 0, $w, $margin)
$g.FillRectangle([System.Drawing.Brushes]::White, 0, 0, $margin, $h)
$g.DrawImage($src, $margin, $margin, $src.Width * $Scale, $src.Height * $Scale)

$ts = 16 * $Scale
$cols = [int]($src.Width / 16)
$rows = [int]($src.Height / 16)
$font = New-Object System.Drawing.Font "Consolas", 9
$gridPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(110, 255, 255, 0)), 1
for ($c = 0; $c -le $cols; $c++) { $x = $margin + $c * $ts; $g.DrawLine($gridPen, $x, $margin, $x, $h) }
for ($r = 0; $r -le $rows; $r++) { $y = $margin + $r * $ts; $g.DrawLine($gridPen, $margin, $y, $w, $y) }
for ($c = 0; $c -lt $cols; $c++) { $g.DrawString("$c", $font, [System.Drawing.Brushes]::Black, $margin + $c * $ts + 2, 6) }
for ($r = 0; $r -lt $rows; $r++) { $g.DrawString("$r", $font, [System.Drawing.Brushes]::Black, 2, $margin + $r * $ts + 2) }

if ($Tscn) {
    $defined = @{}
    $polys = @()
    foreach ($line in Get-Content $Tscn) {
        if ($line -match '^(\d+):(\d+)/0 = 0') { $defined["$($Matches[1]),$($Matches[2])"] = $true }
        if ($line -match '^(\d+):(\d+)/0/physics_layer_0/polygon_\d+/points = PackedVector2Array\((.*)\)') {
            $polys += , @([int]$Matches[1], [int]$Matches[2], $Matches[3])
        }
    }
    # Grey cross on tiles NOT defined in the TileSet (cannot be painted).
    $undefPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(160, 255, 255, 255)), 1
    for ($c = 0; $c -lt $cols; $c++) {
        for ($r = 0; $r -lt $rows; $r++) {
            if (-not $defined.ContainsKey("$c,$r")) {
                $x = $margin + $c * $ts; $y = $margin + $r * $ts
                $g.DrawLine($undefPen, $x + 4, $y + 4, $x + $ts - 4, $y + $ts - 4)
                $g.DrawLine($undefPen, $x + $ts - 4, $y + 4, $x + 4, $y + $ts - 4)
            }
        }
    }
    if (-not $NoCollision) {
        $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(90, 255, 0, 0))
        $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(230, 255, 40, 40)), 2
        foreach ($p in $polys) {
            $nums = $p[2] -split ',\s*' | ForEach-Object { [double]$_ }
            $pts = @()
            for ($i = 0; $i -lt $nums.Count; $i += 2) {
                $cx = $margin + $p[0] * $ts + $ts / 2 + $nums[$i] * $Scale
                $cy = $margin + $p[1] * $ts + $ts / 2 + $nums[$i + 1] * $Scale
                $pts += New-Object System.Drawing.PointF ([single]$cx), ([single]$cy)
            }
            if ($pts.Count -ge 3) { $g.FillPolygon($brush, $pts); $g.DrawPolygon($pen, $pts) }
        }
    }
}
$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose(); $src.Dispose()
"saved $Out"
