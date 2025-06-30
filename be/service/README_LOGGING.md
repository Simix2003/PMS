# Log Collection on Windows

This document describes how to install and configure **Filebeat** on a Windows host so that the PMS application logs are forwarded to the central 3Sun log collector.

## 1. Installation

1. Download the latest Filebeat zip archive for Windows from the [Elastic downloads](https://www.elastic.co/downloads/beats/filebeat) page.
2. Extract the archive, e.g. to `C:\Program Files\Filebeat`.
3. From an **Administrator** PowerShell prompt, run the following to install Filebeat as a service:
   ```powershell
   cd 'C:\Program Files\Filebeat'
   .\install-service-filebeat.ps1
   ```

## 2. Configuration

Edit `filebeat.yml` located in the Filebeat directory. Below is a minimal configuration that tails the PMS application logs and sends them to the log collector. Replace the log file path and collector host/port with the values provided by 3Sun.

```yaml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - C:\\PMS\\logs\\*.log

output.logstash:
  hosts: ["logcollector.3sun.local:5044"]
```

After saving the configuration, start the service (or restart if it was already running):

```powershell
Start-Service filebeat
```

Filebeat will now watch the specified log files and forward entries to the central log collector.

To start : 

cd 'C:\Program Files\Elastic\Beats\9.0.3\filebeat'

.\filebeat.exe -e -c filebeat.yml

