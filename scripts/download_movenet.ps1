param(
    [ValidateSet("lightning", "thunder")]
    [string]$Model = "lightning"
)

$models = @{
    "lightning" = @{
        Url = "https://www.kaggle.com/api/v1/models/google/movenet/tfLite/singlepose-lightning-tflite-float16/1/download"
        File = "movenet_lightning.tflite"
    }
    "thunder" = @{
        Url = "https://www.kaggle.com/api/v1/models/google/movenet/tfLite/singlepose-thunder-tflite-float16/1/download"
        File = "movenet_thunder.tflite"
    }
}

$dest = Resolve-Path (Join-Path $PSScriptRoot "..\assets\tflite")
$info = $models[$Model]
$outPath = Join-Path $dest $info.File

Write-Host "Downloading $($info.File)..." -ForegroundColor Cyan
Write-Host "  ->  $outPath" -ForegroundColor Gray

try {
    $gzPath = "$outPath.gz"
    curl.exe -L -o $gzPath $info.Url 2>&1 | Out-Null
    if ((Get-Item $gzPath).Length -gt 10000) {
        tar -xzf $gzPath -C $dest 2>&1 | Out-Null
        Get-ChildItem $dest -Filter "*.tflite" | Where-Object { $_.Name -ne $info.File } | Rename-Item -NewName $info.File -ErrorAction SilentlyContinue
        Remove-Item $gzPath -ErrorAction SilentlyContinue
        $size = (Get-Item $outPath).Length
        Write-Host "Done! ($($size / 1MB -as [int]) MB)" -ForegroundColor Green
    } else {
        Write-Host "Download failed: response too small" -ForegroundColor Red
    }
}
catch {
    Write-Host "Download failed: $_" -ForegroundColor Red
}
