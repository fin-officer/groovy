# Windows Setup Guide for Email-LLM Integration

This guide provides step-by-step instructions for setting up and running the Email-LLM Integration project on Windows.

## Prerequisites

- **Windows 10/11** (64-bit)
- **PowerShell 5.1 or later** (included with Windows 10/11)
- **Administrator privileges** (required for installation)
- **Internet connection** (for downloading dependencies)

## Quick Start

1. **Run the installation script** (as Administrator):
   ```powershell
   # 1. Open PowerShell as Administrator
   # 2. Navigate to your project directory
   cd path\to\project
   
   # 3. Allow script execution (one-time setup)
   Set-ExecutionPolicy Bypass -Scope Process -Force
   
   # 4. Run the installation script
   .\install-dependencies.ps1
   ```
   This will install:
   - Docker Desktop
   - Git
   - Required Windows features
   - Docker Compose

2. **After installation completes**:
   - If prompted, restart your computer
   - Make sure Docker Desktop is running (you should see the Docker icon in the system tray)

3. **Clone the repository** (if not already done):
   ```powershell
   git clone https://github.com/fin-officer/groovy.git
   cd groovy
   ```

4. **Run the setup script**:
   ```powershell
   .\setup.ps1
   ```
   This will:
   - Verify system requirements
   - Create necessary directories
   - Set up the project structure

## Running the Application

### Start the System

Open PowerShell and navigate to your project directory, then run:

```powershell
# Start all services
.\start.ps1
```

This will:
1. Check if Docker is running
2. Verify port availability
3. Create necessary directories with proper permissions
4. Start all required containers
5. Display the status of each service

### Accessing Services

Once started, you can access:
- **Mailhog UI**: http://localhost:8026
- **Adminer**: http://localhost:8081

> **Note**: The first startup might take a few minutes as Docker downloads the required images.

### Stop the System

```powershell
.\stop.ps1
```

This will:
1. Stop all running containers
2. Clean up resources
3. Display a success message when complete

## Troubleshooting

### Common Issues

1. **Installation Fails**
   - Make sure you're running PowerShell as Administrator
   - Check your internet connection
   - Ensure your system meets the minimum requirements

2. **Docker Not Running**
   - Make sure Docker Desktop is running (check system tray)
   - If Docker fails to start, try:
     - Restarting your computer
     - Running Docker Desktop as Administrator
     - Checking for Docker Desktop updates

3. **Port Conflicts**
   If you see port conflict errors:
   ```powershell
   # Check which process is using a port
   netstat -ano | findstr :<port>
   
   # Then stop the process or modify the port in .env file
   ```

4. **Permission Issues**
   - Run PowerShell as Administrator
   - Make sure your user has proper permissions on the project directory

5. **Script Execution**
   If scripts don't run:
   ```powershell
   # Check execution policy
   Get-ExecutionPolicy
   
   # If needed, set execution policy
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

6. **Docker Containers Not Starting**
   - Check Docker logs:
     ```powershell
     docker-compose logs
     ```
   - Make sure you have enough disk space
   - Try rebuilding the containers:
     ```powershell
     docker-compose down
     docker-compose up -d --build
     ```

### Viewing Logs

```powershell
# View container logs
docker-compose logs -f

# View logs for a specific service
docker-compose logs -f service_name
```

## Windows-Specific Notes

### Performance Optimization

1. **WSL 2 Configuration**
   - Ensure WSL 2 is enabled (should be done by the install script)
   - In Docker Desktop Settings > Resources > WSL Integration, enable integration with your WSL 2 distro

2. **Resource Allocation**
   - In Docker Desktop Settings > Resources:
     - Allocate at least 4-8GB of RAM
     - Allocate at least 2 CPU cores
     - Increase swap file size if needed

3. **File Sharing**
   - Add your project directory to Docker's file sharing list in Settings > Resources > File Sharing

### Development Environment

1. **VS Code Setup**
   - Install the following extensions:
     - Docker
     - Remote - WSL
     - PowerShell
   - Set line endings to LF for shell scripts:
     ```json
     "files.eol": "\n",
     "files.autoGuessEncoding": true
     ```

2. **Terminal**
   - Use Windows Terminal for better experience
   - Configure your profile to use PowerShell Core

### Security

1. **Antivirus**
   - Add exceptions for:
     - Docker Desktop installation directory
     - WSL 2 virtual disk
     - Your project directory

2. **Firewall**
   - Allow Docker through Windows Defender Firewall
   - If using another firewall, create rules for Docker executables

### Troubleshooting Commands

```powershell
# Check Docker status
docker info
docker ps -a

# Check WSL status
wsl --list --verbose

# View logs
docker-compose logs -f

# Clean up unused resources
docker system prune -a
```

### Updating

To update your environment:

1. Update Docker Desktop through the application
2. Update WSL 2 kernel (if prompted)
3. Update project dependencies:
   ```powershell
   git pull
   .\stop.ps1
   docker-compose pull
   .\start.ps1
   ```

## Advanced Configuration

### Environment Variables

Create a `.env` file in the project root to customize settings:

```env
# Database
DB_HOST=db
DB_PORT=3306
DB_NAME=app_db
DB_USER=user
DB_PASSWORD=password

# Ports
MAILHOG_UI_PORT=8026
ADMINER_PORT=8081

# Other settings
TZ=Europe/Warsaw
```

### Docker Compose Overrides

Create a `docker-compose.override.yml` to customize services:

```yaml
version: '3.8'

services:
  app:
    environment:
      - DEBUG=true
    volumes:
      - ./:/app
    ports:
      - "8080:8080"
```

## Maintenance

### Updating Dependencies

1. **Update Docker Images**:
   ```powershell
   docker-compose pull
   ```

2. **Rebuild Services**:
   ```powershell
   docker-compose up -d --build
   ```

3. **Clean Up**:
   ```powershell
   # Remove unused containers, networks, and images
docker system prune

# Remove all unused volumes
docker volume prune
   ```

### Backup and Restore

1. **Backup Database**:
   ```powershell
   # Create backup
docker exec -t <container_name> pg_dump -U <username> <database_name> > backup.sql
   ```

2. **Restore Database**:
   ```powershell
   # Copy backup to container
docker cp backup.sql <container_name>:/backup.sql

# Restore from backup
docker exec -it <container_name> psql -U <username> <database_name> < /backup.sql
   ```

## Getting Help

For additional assistance:

1. Check the logs:
   ```powershell
   docker-compose logs -f
   ```

2. Check service status:
   ```powershell
   docker-compose ps
   ```

3. Access container shell:
   ```powershell
   docker-compose exec <service_name> /bin/bash
   ```

4. View resource usage:
   ```powershell
   docker stats
   ```

5. Check Docker system information:
   ```powershell
   docker system df
   docker info
   ```

## Contributing

1. Create a feature branch
2. Make your changes
3. Test thoroughly
4. Submit a pull request

## License

[Your project license information here]

## Getting Help

For additional assistance, please refer to:
- Project documentation in the `docs/` directory
- Docker documentation: https://docs.docker.com/
- PowerShell documentation: https://docs.microsoft.com/en-us/powershell/
