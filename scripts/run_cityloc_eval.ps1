param(
    [ValidateSet("CityLoc-K", "CityLoc-C")]
    [string]$Dataset = "CityLoc-K",

    [ValidateSet("val", "test")]
    [string]$Split = "val",

    [switch]$CoarseOnly,

    [int]$BatchSize = 8,

    [int[]]$Threshs = @(5, 10, 15),

    [string]$RepoRoot = "I:\Github storage\CMMLocPP - Copy",

    [string]$PythonExe = "C:\Users\Turza\anaconda3\envs\cmmloc_new\python.exe"
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

$checkpointRoot = Join-Path $RepoRoot "checkpoints\k360_30-10_scG_pd10_pc4_spY_all"
$coarse = Join-Path $checkpointRoot "coarse_contN_epoch6_acc0.788_ecl0_eco0_p256_npa1_loss-contrastive_f-class-color-position-num.pth"
$fine = Join-Path $checkpointRoot "fine_contN_epoch15_offset0.100_lr0.0003_obj-6-16_ecl0_eco0_p256_npa1_f-class-color-position-num.pth"
$pointnet = Join-Path $checkpointRoot "best_pointnet.pth"
$prealignColor = Join-Path $checkpointRoot "best_color_encoder.pth"
$prealignMlp = Join-Path $checkpointRoot "best_mlp.pth"

if ($Dataset -eq "CityLoc-K") {
    $basePath = Join-Path $RepoRoot "Cityloc dataset\CityLoc-K\k360_50-10_gridCells_pd10_pc2_shiftPoses_all_nm-6_v5"
    $evalSplit = if ($Split -eq "test") { "cityloc_k_test" } else { "cityloc_k_val" }
}
else {
    if ($Split -eq "test") {
        throw "CityLoc-C only provides a validation split in the downloaded VLM-Loc package."
    }
    $basePath = Join-Path $RepoRoot "Cityloc dataset\CityLoc-C\cityrefer_data_v3"
    $evalSplit = "cityloc_c_val"
}

$required = @($basePath, $coarse, $fine, $pointnet, $prealignColor, $prealignMlp)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required path: $path"
    }
}
if (-not (Test-Path -LiteralPath $PythonExe)) {
    throw "Missing Python executable: $PythonExe"
}

$cmd = @(
    "-m", "evaluation.pipeline",
    "--batch_size", "$BatchSize",
    "--base_path", $basePath,
    "--eval_split", $evalSplit,
    "--target_cell_attr", "eval_cell_id",
    "--use_features", "class", "color", "position", "num",
    "--no_pc_augment",
    "--no_pc_augment_fine",
    "--hungging_model", "t5-large",
    "--fixed_embedding",
    "--text_max_length", "128",
    "--pointnet_path", $pointnet,
    "--prealign_pointnet_path", $pointnet,
    "--prealign_color_path", $prealignColor,
    "--prealign_mlp_path", $prealignMlp,
    "--path_coarse", $coarse,
    "--path_fine", $fine,
    "--rerank_topn", "50",
    "--rerank_base_weight", "1.0",
    "--rerank_label_weight", "0.6",
    "--rerank_color_weight", "1.0",
    "--threshs"
) + $Threshs

if ($CoarseOnly) {
    $cmd += "--coarse_only"
}

Write-Host "CityLoc evaluation"
Write-Host "Dataset: $Dataset"
Write-Host "Split: $Split ($evalSplit)"
Write-Host "Mode: structure + fixed symbolic rerank"
Write-Host "Target cell: eval_cell_id"
Write-Host "Base path: $basePath"
Write-Host "Coarse checkpoint: $coarse"
Write-Host "Fine checkpoint: $fine"
Write-Host "Python: $PythonExe"
Write-Host ""
Write-Host "Running: `"$PythonExe`" $($cmd -join ' ')"
Write-Host ""

& $PythonExe @cmd
