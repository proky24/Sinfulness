param([string]$Png, [int]$X0, [int]$Y0, [int]$X1, [int]$Y1, [int]$Scale = 8, [string]$Out)
# Crops tiles X0..X1, Y0..Y1 (inclusive) and scales them with a labelled grid.
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile($Png)
$cols = $X1 - $X0 + 1; $rows = $Y1 - $Y0 + 1
$ts = 16 * $Scale; $m = 30
$bmp = New-Object System.Drawing.Bitmap ($cols * $ts + $m), ($rows * $ts + $m)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g.Clear([System.Drawing.Color]::FromArgb(255, 255, 0, 255))
$g.FillRectangle([System.Drawing.Brushes]::White, 0, 0, $bmp.Width, $m)
$g.FillRectangle([System.Drawing.Brushes]::White, 0, 0, $m, $bmp.Height)
$dst = New-Object System.Drawing.Rectangle $m, $m, ($cols * $ts), ($rows * $ts)
$g.DrawImage($src, $dst, ($X0 * 16), ($Y0 * 16), ($cols * 16), ($rows * 16), [System.Drawing.GraphicsUnit]::Pixel)
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(140, 255, 255, 0)), 1
$font = New-Object System.Drawing.Font "Consolas", 10
for ($c = 0; $c -le $cols; $c++) { $g.DrawLine($pen, $m + $c * $ts, $m, $m + $c * $ts, $bmp.Height) }
for ($r = 0; $r -le $rows; $r++) { $g.DrawLine($pen, $m, $m + $r * $ts, $bmp.Width, $m + $r * $ts) }
for ($c = 0; $c -lt $cols; $c++) { $g.DrawString("$($X0 + $c)", $font, [System.Drawing.Brushes]::Black, $m + $c * $ts + 4, 8) }
for ($r = 0; $r -lt $rows; $r++) { $g.DrawString("$($Y0 + $r)", $font, [System.Drawing.Brushes]::Black, 2, $m + $r * $ts + 4) }
$g.Dispose(); $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); $src.Dispose()
"saved $Out"
