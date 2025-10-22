# ARM64 Docker Deployment Guide for AegisEdgeAI

This guide shows how to deploy AegisEdgeAI in Docker containers on ARM64 devices.

## Quick Start

### Prerequisites
- ARM64 device (Raspberry Pi, ARM64 server, etc.)
- Docker and Docker Compose installed
- At least 2GB RAM (4GB+ recommended)
- Network connectivity for downloading dependencies

### 1. Install Docker (if not already installed)
```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install Docker Compose (if needed)
sudo apt-get update
sudo apt-get install docker-compose-plugin
```

### 2. Clone and Deploy
```bash
# Clone the repository
git clone https://github.com/lfedgeai/AegisEdgeAI.git
cd AegisEdgeAI

# Deploy on ARM64
./deploy-arm64.sh
```

### 3. Access Services
- **Agent Service**: http://localhost:5000
- **Collector Service**: http://localhost:5001  
- **Gateway Service**: http://localhost:5002
- **Monitoring**: http://localhost:9090

## Deployment Options

### Option 1: Full Automated Deployment
```bash
./deploy-arm64.sh deploy
```
This will:
- Build the ARM64 Docker image
- Start all services with Docker Compose
- Run validation tests
- Show deployment status

### Option 2: Step-by-Step Deployment
```bash
# Build image only
./deploy-arm64.sh build

# Deploy services
./deploy-arm64.sh deploy

# Check status
./deploy-arm64.sh status

# Run tests
./deploy-arm64.sh test
```

### Option 3: Manual Docker Build
```bash
# Build ARM64 image
docker buildx build --platform linux/arm64 -f Dockerfile.arm64 -t aegis-edge-ai:arm64-latest .

# Run with Docker Compose
docker-compose -f docker-compose.arm64.yml up -d
```

## Configuration

### Environment Variables
The following environment variables can be customized:

```bash
# Architecture (automatically detected)
ARCH=aarch64

# TPM Configuration
TPM2TOOLS_TCTI=swtpm:host=127.0.0.1,port=2321

# Application Settings
FLASK_ENV=production
PYTHONPATH=/app
```

### Resource Limits
The Docker Compose file includes resource limits suitable for edge devices:

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 2G
    reservations:
      cpus: '0.5'
      memory: 512M
```

### Persistent Storage
Data is persisted in the following volumes:
- `./data` - Application data
- `./logs` - Service logs
- `tpm-state` - TPM state and keys

## Troubleshooting

### Build Issues
```bash
# Check Docker BuildKit is enabled
export DOCKER_BUILDKIT=1

# View build logs
docker buildx build --platform linux/arm64 -f Dockerfile.arm64 --progress=plain .
```

### Runtime Issues
```bash
# Check container logs
docker-compose -f docker-compose.arm64.yml logs

# Check individual service
docker-compose -f docker-compose.arm64.yml logs aegis-edge-ai

# Check TPM functionality
docker-compose -f docker-compose.arm64.yml exec aegis-edge-ai swtpm --version
```

### Performance Issues
```bash
# Monitor resource usage
docker stats

# Check ARM64 optimization
docker-compose -f docker-compose.arm64.yml exec aegis-edge-ai uname -m
```

## Architecture-Specific Features

### ARM64 Optimizations
- **Compiler Flags**: Uses `-march=armv8-a` for optimal ARM64 performance
- **Native Compilation**: TPM stack compiled specifically for ARM64
- **Memory Efficiency**: Optimized for edge device memory constraints

### TPM Stack Components
All components built from source for ARM64:
- **libtpms**: TPM library implementation
- **swtpm**: Software TPM emulator
- **tpm2-tss**: TPM 2.0 System Software stack
- **tpm2-tools**: Command-line tools for TPM 2.0

### Multi-Stage Build
The Dockerfile uses multi-stage builds to minimize final image size:
1. **Builder stage**: Compiles all TPM components from source
2. **Runtime stage**: Contains only runtime dependencies and built binaries

## Cloud Deployment

### AWS Graviton Instances
```bash
# Launch ARM64 instance
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --instance-type c7g.large \
  --key-name your-key-pair

# Deploy AegisEdgeAI
ssh ec2-user@your-instance
git clone https://github.com/lfedgeai/AegisEdgeAI.git
cd AegisEdgeAI
./deploy-arm64.sh
```

### Google Cloud T2A
```bash
# Create ARM64 VM
gcloud compute instances create aegis-t2a \
  --machine-type=t2a-standard-2 \
  --image-family=ubuntu-2204-lts-arm64 \
  --image-project=ubuntu-os-cloud

# Deploy AegisEdgeAI
gcloud compute ssh aegis-t2a
./deploy-arm64.sh
```

### Azure Ampere
```bash
# Create ARM64 VM  
az vm create \
  --resource-group myResourceGroup \
  --name aegis-ampere \
  --size Standard_D2ps_v5 \
  --image Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest

# Deploy AegisEdgeAI
az vm run-command invoke \
  --resource-group myResourceGroup \
  --name aegis-ampere \
  --command-id RunShellScript \
  --scripts "git clone https://github.com/lfedgeai/AegisEdgeAI.git && cd AegisEdgeAI && ./deploy-arm64.sh"
```

## Edge Device Deployment

### Raspberry Pi
```bash
# Ensure sufficient resources
# Raspberry Pi 4 with 4GB+ RAM recommended

# Enable memory split for TPM operations
echo 'gpu_mem=16' >> /boot/config.txt
sudo reboot

# Deploy
./deploy-arm64.sh
```

### NVIDIA Jetson
```bash
# Use JetPack-compatible base image
# Modify Dockerfile.arm64 if needed for CUDA support

./deploy-arm64.sh
```

## Management Commands

### Service Management
```bash
# Start services
./deploy-arm64.sh deploy

# Stop services
./deploy-arm64.sh stop

# Restart services
docker-compose -f docker-compose.arm64.yml restart

# Update services
git pull
./deploy-arm64.sh build
docker-compose -f docker-compose.arm64.yml up -d
```

### Monitoring
```bash
# View real-time logs
docker-compose -f docker-compose.arm64.yml logs -f

# Check service health
curl http://localhost:5000/health

# Monitor resource usage
docker stats --no-stream
```

### Backup and Recovery
```bash
# Backup TPM state and data
docker-compose -f docker-compose.arm64.yml exec aegis-edge-ai tar -czf /tmp/backup.tar.gz /var/lib/swtpm-localca /app/data

# Copy backup out of container
docker cp aegis-edge-ai-arm64:/tmp/backup.tar.gz ./backup-$(date +%Y%m%d).tar.gz

# Restore from backup
docker cp ./backup-20231201.tar.gz aegis-edge-ai-arm64:/tmp/
docker-compose -f docker-compose.arm64.yml exec aegis-edge-ai tar -xzf /tmp/backup-20231201.tar.gz -C /
```

## Security Considerations

### Container Security
- Runs as non-root user (`aegis`)
- Limited resource allocation
- Read-only configuration mounts
- Network isolation via dedicated bridge

### TPM Security
- Software TPM state persisted in named volume
- TPM communication on isolated ports
- Hardware TPM support available if device equipped

### Network Security
- Services exposed only on localhost by default
- Use reverse proxy (nginx/traefik) for external access
- Enable HTTPS in production

## Performance Tuning

### Memory Optimization
```bash
# Reduce logging verbosity
export FLASK_ENV=production

# Optimize Docker for ARM64
echo '{"experimental": true, "features": {"buildkit": true}}' > ~/.docker/config.json
```

### CPU Optimization
```bash
# Use all available cores for compilation
export MAKEFLAGS="-j$(nproc)"

# Set CPU affinity for critical services
docker-compose -f docker-compose.arm64.yml exec aegis-edge-ai taskset -c 0-1 python3 agent/app.py
```

## Integration Examples

### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aegis-edge-ai-arm64
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aegis-edge-ai
  template:
    metadata:
      labels:
        app: aegis-edge-ai
    spec:
      nodeSelector:
        kubernetes.io/arch: arm64
      containers:
      - name: aegis-edge-ai
        image: aegis-edge-ai:arm64-latest
        ports:
        - containerPort: 5000
        resources:
          limits:
            memory: "2Gi"
            cpu: "2000m"
          requests:
            memory: "512Mi"
            cpu: "500m"
```

### Docker Swarm
```bash
# Initialize swarm on ARM64 manager
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.arm64.yml aegis-stack
```

## Support

For ARM64-specific issues:
1. Check the ARM64 documentation: `docs/arm64-support.md`
2. Run validation tests: `./test-arm64-implementation.sh`
3. Review container logs: `docker-compose -f docker-compose.arm64.yml logs`
4. Report issues on GitHub with ARM64 label