#!/bin/bash

# ARM64 Docker Deployment Script for AegisEdgeAI
# This script builds and deploys AegisEdgeAI on ARM64 devices

set -euo pipefail

echo "=== AegisEdgeAI ARM64 Docker Deployment ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
COMPOSE_FILE="docker-compose.arm64.yml"
DOCKERFILE="Dockerfile.arm64"
IMAGE_NAME="aegis-edge-ai:arm64-latest"
CONTAINER_NAME="aegis-edge-ai-arm64"

# Function to print status
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on ARM64
check_architecture() {
    local arch=$(uname -m)
    print_status "Detected architecture: $arch"
    
    if [[ "$arch" != "aarch64" && "$arch" != "arm64" ]]; then
        print_warning "Not running on ARM64 architecture. This script is optimized for ARM64 devices."
        print_status "Proceeding with cross-platform build..."
    else
        print_success "ARM64 architecture confirmed"
    fi
}

# Check Docker installation
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed. Please install Docker first:"
        echo "  curl -fsSL https://get.docker.com | sh"
        echo "  sudo usermod -aG docker \$USER"
        exit 1
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose is not installed. Please install Docker Compose."
        exit 1
    fi
    
    print_success "Docker and Docker Compose are available"
}

# Enable Docker BuildKit and multi-platform support
setup_docker_buildx() {
    print_status "Setting up Docker BuildKit and multi-platform support..."
    
    # Enable BuildKit
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    
    # Create/use buildx builder for multi-platform builds
    if ! docker buildx ls | grep -q "aegis-builder"; then
        print_status "Creating multi-platform buildx builder..."
        docker buildx create --name aegis-builder --use --bootstrap
    else
        print_status "Using existing buildx builder..."
        docker buildx use aegis-builder
    fi
    
    print_success "Docker BuildKit configured"
}

# Create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    
    mkdir -p data logs monitoring
    
    # Create monitoring configuration
    if [ ! -f "monitoring/prometheus.yml" ]; then
        cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'aegis-edge-ai'
    static_configs:
      - targets: ['aegis-edge-ai:5000', 'aegis-edge-ai:5001', 'aegis-edge-ai:5002']
    scrape_interval: 10s
    metrics_path: /metrics
EOF
    fi
    
    print_success "Directories created"
}

# Build the ARM64 image
build_image() {
    print_status "Building ARM64 Docker image..."
    print_status "This may take 10-15 minutes as we compile the TPM stack from source..."
    
    # Build with BuildKit for better caching and performance
    docker buildx build \
        --platform linux/arm64 \
        --file "$DOCKERFILE" \
        --tag "$IMAGE_NAME" \
        --load \
        . || {
        print_error "Failed to build Docker image"
        exit 1
    }
    
    print_success "ARM64 Docker image built successfully"
}

# Test the built image
test_image() {
    print_status "Testing the built image..."
    
    # Run basic tests
    if docker run --rm --platform linux/arm64 "$IMAGE_NAME" uname -m | grep -q "aarch64"; then
        print_success "ARM64 architecture confirmed in container"
    else
        print_error "Architecture test failed"
        exit 1
    fi
    
    # Test TPM tools availability
    if docker run --rm --platform linux/arm64 "$IMAGE_NAME" which swtpm >/dev/null 2>&1; then
        print_success "TPM tools available in container"
    else
        print_error "TPM tools test failed"
        exit 1
    fi
    
    print_success "Image tests passed"
}

# Deploy with Docker Compose
deploy_services() {
    print_status "Deploying AegisEdgeAI services..."
    
    # Stop existing services if running
    if docker-compose -f "$COMPOSE_FILE" ps -q | grep -q .; then
        print_status "Stopping existing services..."
        docker-compose -f "$COMPOSE_FILE" down
    fi
    
    # Start services
    docker-compose -f "$COMPOSE_FILE" up -d
    
    print_success "Services deployed"
}

# Wait for services to be ready
wait_for_services() {
    print_status "Waiting for services to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
            print_success "Services are running"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "Services failed to start within timeout"
            docker-compose -f "$COMPOSE_FILE" logs
            exit 1
        fi
        
        print_status "Attempt $attempt/$max_attempts - waiting for services..."
        sleep 5
        ((attempt++))
    done
}

# Show deployment status
show_status() {
    print_status "Deployment Status:"
    echo ""
    
    # Show running containers
    docker-compose -f "$COMPOSE_FILE" ps
    echo ""
    
    # Show service URLs
    print_success "AegisEdgeAI Services:"
    echo "  Agent Service:     http://localhost:5000"
    echo "  Collector Service: http://localhost:5001"
    echo "  Gateway Service:   http://localhost:5002"
    echo "  Monitoring:        http://localhost:9090"
    echo ""
    
    # Show logs command
    print_status "To view logs:"
    echo "  docker-compose -f $COMPOSE_FILE logs -f"
    echo ""
    
    # Show stop command
    print_status "To stop services:"
    echo "  docker-compose -f $COMPOSE_FILE down"
}

# Run ARM64 validation tests
run_validation() {
    print_status "Running ARM64 validation tests..."
    
    if [ -f "test-arm64-implementation.sh" ]; then
        # Run tests inside the container
        docker-compose -f "$COMPOSE_FILE" exec -T aegis-edge-ai ./test-arm64-implementation.sh || {
            print_warning "Some validation tests failed. Check the logs for details."
        }
    else
        print_warning "ARM64 test script not found, skipping validation"
    fi
}

# Cleanup function
cleanup() {
    if [ "${1:-}" = "EXIT" ]; then
        print_status "Cleaning up..."
        # Could add cleanup logic here if needed
    fi
}

# Set trap for cleanup
trap 'cleanup EXIT' EXIT

# Main deployment flow
main() {
    echo -e "Running on: ${YELLOW}$(uname -s) $(uname -m)${NC}"
    echo -e "Date: ${YELLOW}$(date)${NC}"
    echo ""
    
    # Verify requirements
    check_architecture
    check_docker
    setup_docker_buildx
    
    # Prepare environment
    create_directories
    
    # Build and test
    build_image
    test_image
    
    # Deploy
    deploy_services
    wait_for_services
    
    # Validate
    run_validation
    
    # Show results
    show_status
    
    print_success "AegisEdgeAI ARM64 deployment completed successfully!"
    echo ""
    print_status "Next steps:"
    echo "  1. Access the web interface at http://localhost:5000"
    echo "  2. Check service logs: docker-compose -f $COMPOSE_FILE logs -f"
    echo "  3. Monitor performance: http://localhost:9090"
}

# Parse command line arguments
case "${1:-deploy}" in
    "build")
        check_docker
        setup_docker_buildx
        build_image
        test_image
        ;;
    "deploy")
        main
        ;;
    "test")
        run_validation
        ;;
    "status")
        show_status
        ;;
    "stop")
        docker-compose -f "$COMPOSE_FILE" down
        print_success "Services stopped"
        ;;
    "clean")
        docker-compose -f "$COMPOSE_FILE" down -v
        docker rmi "$IMAGE_NAME" 2>/dev/null || true
        print_success "Cleanup completed"
        ;;
    *)
        echo "Usage: $0 {build|deploy|test|status|stop|clean}"
        echo ""
        echo "Commands:"
        echo "  build   - Build ARM64 Docker image only"
        echo "  deploy  - Full deployment (build + deploy + test)"
        echo "  test    - Run validation tests"
        echo "  status  - Show deployment status"
        echo "  stop    - Stop running services"
        echo "  clean   - Stop services and remove images/volumes"
        exit 1
        ;;
esac