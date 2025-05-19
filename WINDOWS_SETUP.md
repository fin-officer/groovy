# Windows Setup Guide for Email-LLM Integration

This guide provides step-by-step instructions for setting up and running the Email-LLM Integration project on Windows.

## Prerequisites

1. **Windows 10/11** (64-bit)
2. **Docker Desktop for Windows**
   - Download from: https://www.docker.com/products/docker-desktop/
   - Enable WSL 2 backend for better performance
   - Allocate at least 4GB of RAM to Docker in Settings > Resources

3. **PowerShell 5.1 or later** (included with Windows 10/11)
4. **Git for Windows** (recommended)
   - Download from: https://git-scm.com/download/win

## Getting Started

### 1. Clone the Repository

```powershell
# Open PowerShell and navigate to your preferred directory
git clone https://github.com/fin-officer/groovy.git
cd groovy
```

### 2. Set Execution Policy (One-time Setup)

To allow running PowerShell scripts, you'll need to set the execution policy:

```powershell
# Run PowerShell as Administrator and execute:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 3. Project Setup

Run the setup script to initialize the project:

```powershell
.\setup.ps1
```

This will:
- Verify system requirements
- Create necessary directories
- Set up the project structure

## Running the Application

### Start the System

```powershell
.\start.ps1
```

This will:
1. Check if Docker is running
2. Verify port availability
3. Create necessary directories with proper permissions
4. Start all required containers

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

1. **Docker Not Running**
   - Make sure Docker Desktop is running
   - Check if the Docker service is started in Services (services.msc)

2. **Port Conflicts**
   If you see port conflict errors, you can either:
   - Stop the service using the conflicting port
   - Modify the port in the `.env` file

3. **Permission Issues**
   If you encounter permission errors, try running PowerShell as Administrator

4. **Script Execution**
   If scripts don't run, ensure:
   - File extensions are correct (`.ps1` for PowerShell scripts)
   - Execution policy allows script execution

### Viewing Logs

```powershell
# View container logs
docker-compose logs -f

# View logs for a specific service
docker-compose logs -f service_name
```

## Windows-Specific Notes

1. **Performance**
   - For better performance, ensure:
     - WSL 2 is enabled in Windows Features
     - Docker Desktop is using WSL 2 backend
     - Sufficient resources are allocated to Docker

2. **Line Endings**
   - When editing files, ensure line endings are set to LF (Unix-style) for scripts
   - In VS Code, check the bottom-right corner for line ending settings

3. **Antivirus**
   - Some antivirus software may interfere with Docker
   - Add exceptions for your project directory in your antivirus settings

## Accessing Services

After starting the system, you can access:

- **Mailhog UI**: http://localhost:8026
- **Adminer**: http://localhost:8081

## Updating the Project

To update your local repository:

```powershell
git pull
```

Then restart the system:

```powershell
.\stop.ps1
.\start.ps1
```

## Getting Help

For additional assistance, please refer to:
- Project documentation in the `docs/` directory
- Docker documentation: https://docs.docker.com/
- PowerShell documentation: https://docs.microsoft.com/en-us/powershell/
