# Local Development Test Script (PowerShell)
# Usage: .\test-local.ps1

param(
    [string]$Action = "start"
)

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check Docker
    try {
        $dockerVersion = docker --version
        Write-Info "Docker found: $dockerVersion"
    }
    catch {
        Write-Error "Docker is not installed or not running"
        exit 1
    }
    
    # Check Docker Compose
    try {
        $composeVersion = docker-compose --version
        Write-Info "Docker Compose found: $composeVersion"
    }
    catch {
        Write-Error "Docker Compose is not installed"
        exit 1
    }
    
    Write-Success "Prerequisites check passed"
}

function Start-LocalEnvironment {
    Write-Info "Starting local development environment..."
    
    # Stop any existing containers
    docker-compose -f docker-compose.local.yml down
    
    # Pull latest images
    Write-Info "Pulling latest images..."
    docker-compose -f docker-compose.local.yml pull
    
    # Build and start services
    Write-Info "Building and starting services..."
    docker-compose -f docker-compose.local.yml up --build -d
    
    # Wait for services to be ready
    Write-Info "Waiting for services to be ready..."
    Start-Sleep -Seconds 30
    
    # Test services
    Test-Services
}

function Test-Services {
    Write-Info "Testing services..."
    
    $services = @(
        @{ Name = "PostgreSQL"; URL = "http://localhost:5432"; Command = "docker-compose -f docker-compose.local.yml exec postgres pg_isready -U postgres" },
        @{ Name = "Redis"; URL = "redis://localhost:6379"; Command = "docker-compose -f docker-compose.local.yml exec redis redis-cli ping" },
        @{ Name = "Elasticsearch"; URL = "http://localhost:9200"; Command = $null },
        @{ Name = "Backend API"; URL = "http://localhost:5000/api/health"; Command = $null },
        @{ Name = "Frontend"; URL = "http://localhost:3000"; Command = $null }
    )
    
    foreach ($service in $services) {
        Write-Info "Testing $($service.Name)..."
        
        if ($service.Command) {
            try {
                Invoke-Expression $service.Command | Out-Null
                Write-Success "$($service.Name) is healthy"
            }
            catch {
                Write-Error "$($service.Name) is not responding"
            }
        }
        elseif ($service.URL -like "http*") {
            try {
                $response = Invoke-WebRequest -Uri $service.URL -TimeoutSec 10 -UseBasicParsing
                if ($response.StatusCode -eq 200) {
                    Write-Success "$($service.Name) is healthy (HTTP $($response.StatusCode))"
                }
                else {
                    Write-Error "$($service.Name) returned HTTP $($response.StatusCode)"
                }
            }
            catch {
                Write-Error "$($service.Name) is not responding: $($_.Exception.Message)"
            }
        }
    }
}

function Show-ServiceInfo {
    Write-Info "Service Information:"
    Write-Host ""
    Write-Host "🌐 Frontend (React):     http://localhost:3000" -ForegroundColor Cyan
    Write-Host "🔧 Backend API (Flask):  http://localhost:5000" -ForegroundColor Cyan
    Write-Host "🗄️  PostgreSQL:          localhost:5432" -ForegroundColor Cyan
    Write-Host "🔍 Elasticsearch:        http://localhost:9200" -ForegroundColor Cyan
    Write-Host "💾 Redis:                localhost:6379" -ForegroundColor Cyan
    Write-Host "🌐 Nginx (Proxy):        http://localhost:80" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📖 API Documentation:    http://localhost:5000/docs" -ForegroundColor Yellow
    Write-Host "🔍 Elasticsearch Head:   http://localhost:9200/_cat/indices?v" -ForegroundColor Yellow
    Write-Host ""
}

function Show-Logs {
    Write-Info "Showing service logs..."
    docker-compose -f docker-compose.local.yml logs -f
}

function Stop-LocalEnvironment {
    Write-Info "Stopping local development environment..."
    docker-compose -f docker-compose.local.yml down
    Write-Success "Environment stopped"
}

function Cleanup-LocalEnvironment {
    Write-Info "Cleaning up local development environment..."
    docker-compose -f docker-compose.local.yml down -v --remove-orphans
    docker system prune -f
    Write-Success "Environment cleaned up"
}

# Main script logic
switch ($Action.ToLower()) {
    "start" {
        Test-Prerequisites
        Start-LocalEnvironment
        Show-ServiceInfo
    }
    "test" {
        Test-Services
    }
    "logs" {
        Show-Logs
    }
    "stop" {
        Stop-LocalEnvironment
    }
    "cleanup" {
        Cleanup-LocalEnvironment
    }
    "restart" {
        Stop-LocalEnvironment
        Start-LocalEnvironment
        Show-ServiceInfo
    }
    default {
        Write-Host "Usage: .\test-local.ps1 [start|test|logs|stop|cleanup|restart]"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  start    - Start all services"
        Write-Host "  test     - Test service health"
        Write-Host "  logs     - Show service logs"
        Write-Host "  stop     - Stop all services"
        Write-Host "  cleanup  - Stop and remove all containers/volumes"
        Write-Host "  restart  - Restart all services"
        exit 1
    }
}
