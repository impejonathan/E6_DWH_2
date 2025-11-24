# Vérifie si Terraform est installé
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "Terraform n'est pas installé ou n'est pas dans le PATH." -ForegroundColor Red
    exit 1
}

Write-Host "=== Initialisation Terraform ===" -ForegroundColor Cyan
terraform init

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur durant terraform init" -ForegroundColor Red
    exit 1
}

Write-Host "=== Verification Terraform ===" -ForegroundColor Cyan
terraform validate

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur durant terraform validate" -ForegroundColor Red
    exit 1
}

Write-Host "=== Generation du plan Terraform ===" -ForegroundColor Cyan
terraform plan -out=tfplan

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur durant terraform plan" -ForegroundColor Red
    exit 1
}

Write-Host "=== Application du plan Terraform ===" -ForegroundColor Cyan
terraform apply -auto-approve tfplan

if ($LASTEXITCODE -eq 0) {
    Write-Host "=== Deploiement Terraform reussi ! ===" -ForegroundColor Green
} else {
    Write-Host "Erreur durant terraform apply" -ForegroundColor Red
}
