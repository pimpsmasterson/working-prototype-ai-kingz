# Cloud GPU Integration for Muse System

**Date:** January 24, 2026  
**Purpose:** Connect AI Kings Muse System to cloud GPU rental services

---

## Current Architecture

The muse system currently connects to ComfyUI via:
- **Endpoint:** `http://127.0.0.1:8188` (configurable via localStorage)
- **Authentication:** None (local instance)
- **API:** Direct ComfyUI REST endpoints
- **Storage:** localStorage for endpoint config

## Cloud Integration Options

### Popular Cloud GPU Services

| Service | API Type | Authentication | Cost Model |
|---------|----------|----------------|------------|
| **RunPod** | REST API | API Key | Pay-per-minute |
| **AWS SageMaker** | REST API | IAM/AWS Key | Pay-per-hour |
| **Google Vertex AI** | REST API | Service Account | Pay-per-use |
| **Azure ML** | REST API | Azure AD | Pay-per-hour |
| **Replicate** | REST API | API Token | Pay-per-request |
| **Together AI** | REST API | API Key | Pay-per-token |
| **Hugging Face** | REST API | API Token | Pay-per-request |

### Recommended Approach: RunPod Integration

RunPod is ideal for ComfyUI workloads due to:
- ✅ Direct ComfyUI support
- ✅ Pay-per-minute billing
- ✅ REST API compatible with existing code
- ✅ GPU selection (RTX 3090, A100, etc.)
- ✅ Persistent storage options

---

## Implementation Plan

### Phase 1: Basic Cloud Connection

#### 1.1 Update ComfyUIIntegration Class

**File:** `assets/js/muse-manager-pro.js`

```javascript
class ComfyUIIntegration {
    constructor() {
        this.baseUrl = 'http://127.0.0.1:8188'; // Default fallback
        this.apiKey = null;
        this.serviceType = 'local'; // 'local', 'runpod', 'replicate', etc.
        this.workflows = {};
        this.authHeaders = {};
    }

    // Enhanced endpoint configuration
    setEndpoint(url, options = {}) {
        this.baseUrl = url;
        this.serviceType = options.serviceType || 'local';
        this.apiKey = options.apiKey || null;
        
        // Set authentication headers based on service
        this.setAuthHeaders();
    }

    setAuthHeaders() {
        this.authHeaders = {};
        
        switch (this.serviceType) {
            case 'runpod':
                if (this.apiKey) {
                    this.authHeaders['Authorization'] = `Bearer ${this.apiKey}`;
                }
                break;
            case 'replicate':
                if (this.apiKey) {
                    this.authHeaders['Authorization'] = `Token ${this.apiKey}`;
                    this.authHeaders['Content-Type'] = 'application/json';
                }
                break;
            case 'together':
                if (this.apiKey) {
                    this.authHeaders['Authorization'] = `Bearer ${this.apiKey}`;
                }
                break;
            // Add other services...
        }
    }

    async submitWorkflow(workflow) {
        const url = (this.serviceType === 'vastai') ? 'http://localhost:3000/api/proxy/prompt' : `${this.baseUrl}/prompt`;
        
        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    ...(this.serviceType !== 'vastai' ? this.authHeaders : {})
                },
                body: JSON.stringify({
                    prompt: workflow,
                    client_id: 'aikings_' + Date.now()
                })
            });

            if (!response.ok) {
                const text = await response.text();
                throw new Error(`ComfyUI request failed: ${response.status} - ${text}`);
            }

            const result = await response.json();
            return result;
        } catch (error) {
            console.error('ComfyUI submission error:', error);
            
            // Enhanced error handling for cloud services
            if (error.message.includes('401')) {
                throw new Error('Authentication failed. Check your API key.');
            } else if (error.message.includes('429')) {
                throw new Error('Rate limit exceeded. Please try again later.');
            } else if (error.message.includes('402')) {
                throw new Error('Payment required. Check your billing.');
            }
            
            throw error;
        }
    }
}
```

#### 1.2 Add Cloud Service Configuration

**File:** `assets/js/ai-kings-studio-pro.js`

```javascript
class StudioAppPro {
    constructor() {
        // ... existing code ...
        this.cloudServices = {
            runpod: {
                name: 'RunPod',
                baseUrl: 'https://api.runpod.ai/v2',
                requiresApiKey: true,
                gpuOptions: ['RTX 3090', 'RTX 4090', 'A100', 'H100']
            },
            replicate: {
                name: 'Replicate',
                baseUrl: 'https://api.replicate.com/v1',
                requiresApiKey: true,
                model: 'stability-ai/sdxl'
            },
            together: {
                name: 'Together AI',
                baseUrl: 'https://api.together.xyz/v1',
                requiresApiKey: true,
                models: ['runwayml/stable-diffusion-v1-5', 'SG161222/Realistic_Vision_V5.1_noVAE']
            }
        };
    }

    async init() {
        // ... existing code ...
        
        // Load cloud service configuration
        this.loadCloudConfig();
        
        // Set ComfyUI endpoint with cloud service
        this.configureCloudEndpoint();
    }

    loadCloudConfig() {
        const config = localStorage.getItem('aikings_cloud_config');
        if (config) {
            try {
                this.cloudConfig = JSON.parse(config);
            } catch (error) {
                console.error('Failed to parse cloud config:', error);
                this.cloudConfig = null;
            }
        }
    }

    configureCloudEndpoint() {
        if (this.cloudConfig) {
            // Use cloud service
            const service = this.cloudServices[this.cloudConfig.service];
            if (service) {
                this.comfyUI.setEndpoint(service.baseUrl, {
                    serviceType: this.cloudConfig.service,
                    apiKey: this.cloudConfig.apiKey
                });
                console.log(`Connected to ${service.name}`);
            }
        } else {
            // Fallback to local
            const comfyEndpoint = localStorage.getItem('comfyui_endpoint') || 'http://127.0.0.1:8188';
            this.comfyUI.setEndpoint(comfyEndpoint);
        }
    }
}
```

#### 1.3 Add Settings UI for Cloud Configuration

**File:** `studio.html` (add to settings modal)

```html
<!-- Cloud GPU Settings -->
<div class="settings-section">
    <h3>Cloud GPU Service</h3>
    
    <div class="form-group">
        <label>Service Provider</label>
        <select id="cloud-service-select">
            <option value="local">Local ComfyUI</option>
            <option value="runpod">RunPod</option>
            <option value="replicate">Replicate</option>
            <option value="together">Together AI</option>
        </select>
    </div>
    
    <div class="form-group" id="api-key-group" style="display: none;">
        <label>API Key</label>
        <input type="password" id="cloud-api-key" placeholder="Enter your API key">
        <small>Get your API key from your cloud provider's dashboard</small>
    </div>
    
    <div class="form-group" id="gpu-select-group" style="display: none;">
        <label>GPU Type (RunPod)</label>
        <select id="gpu-type-select">
            <option value="RTX 3090">RTX 3090</option>
            <option value="RTX 4090">RTX 4090</option>
            <option value="A100">A100</option>
            <option value="H100">H100</option>
        </select>
    </div>
    
    <button id="test-cloud-connection" class="btn-secondary">Test Connection</button>
    <div id="connection-status"></div>
</div>
```

### Phase 2: Advanced Cloud Features

#### 2.1 Job Queue Management

```javascript
class CloudJobManager {
    constructor(comfyUI) {
        this.comfyUI = comfyUI;
        this.queue = [];
        this.activeJobs = new Map();
        this.maxConcurrent = 2; // Limit concurrent jobs
    }

    async submitJob(workflow, priority = 'normal') {
        const job = {
            id: 'job_' + Date.now(),
            workflow,
            priority,
            status: 'queued',
            submittedAt: new Date(),
            retries: 0
        };

        this.queue.push(job);
        this.processQueue();
        
        return job.id;
    }

    async processQueue() {
        if (this.activeJobs.size >= this.maxConcurrent) return;
        
        const nextJob = this.getNextJob();
        if (!nextJob) return;

        nextJob.status = 'running';
        this.activeJobs.set(nextJob.id, nextJob);

        try {
            const result = await this.comfyUI.submitWorkflow(nextJob.workflow);
            nextJob.result = result;
            nextJob.status = 'completed';
        } catch (error) {
            nextJob.error = error;
            nextJob.status = 'failed';
            
            // Retry logic
            if (nextJob.retries < 3) {
                nextJob.retries++;
                nextJob.status = 'retrying';
                setTimeout(() => this.processQueue(), 5000 * nextJob.retries);
                return;
            }
        }

        this.activeJobs.delete(nextJob.id);
        this.processQueue(); // Process next job
    }

    getNextJob() {
        // Priority-based job selection
        return this.queue
            .filter(job => job.status === 'queued')
            .sort((a, b) => {
                const priorityOrder = { high: 3, normal: 2, low: 1 };
                return priorityOrder[b.priority] - priorityOrder[a.priority];
            })[0];
    }
}
```

#### 2.2 Billing Integration

```javascript
class BillingManager {
    constructor() {
        this.usage = {
            totalCost: 0,
            jobsCompleted: 0,
            gpuTime: 0, // minutes
            dataTransferred: 0 // MB
        };
        this.costPerMinute = 0.5; // Example rate
    }

    trackJob(job, result) {
        if (result && result.executionTime) {
            const cost = result.executionTime * this.costPerMinute;
            this.usage.totalCost += cost;
            this.usage.jobsCompleted++;
            this.usage.gpuTime += result.executionTime;
            
            // Save to localStorage
            localStorage.setItem('aikings_billing', JSON.stringify(this.usage));
        }
    }

    getUsageReport() {
        return {
            ...this.usage,
            averageCostPerJob: this.usage.jobsCompleted > 0 ? 
                this.usage.totalCost / this.usage.jobsCompleted : 0
        };
    }
}
```

#### 2.3 Service Health Monitoring

```javascript
class ServiceHealthMonitor {
    constructor(comfyUI) {
        this.comfyUI = comfyUI;
        this.healthChecks = new Map();
        this.checkInterval = 30000; // 30 seconds
        this.startMonitoring();
    }

    startMonitoring() {
        setInterval(() => this.performHealthCheck(), this.checkInterval);
    }

    async performHealthCheck() {
        try {
            const response = await fetch(`${this.comfyUI.baseUrl}/system_stats`, {
                headers: this.comfyUI.authHeaders,
                timeout: 5000
            });
            
            const isHealthy = response.ok;
            this.healthChecks.set('comfyui', {
                healthy: isHealthy,
                lastCheck: new Date(),
                responseTime: Date.now() - startTime
            });
            
            if (!isHealthy) {
                this.handleServiceDegradation();
            }
        } catch (error) {
            this.healthChecks.set('comfyui', {
                healthy: false,
                lastCheck: new Date(),
                error: error.message
            });
        }
    }

    handleServiceDegradation() {
        // Switch to backup endpoint or show warning
        console.warn('ComfyUI service degraded, switching to backup...');
        // Implementation for failover
    }
}
```

### Phase 3: UI Enhancements

#### 3.1 Connection Status Indicator

```html
<!-- Add to studio.html header -->
<div id="cloud-status-indicator" class="status-indicator">
    <i class="ph ph-cloud"></i>
    <span id="cloud-status-text">Local</span>
    <div class="status-dot" id="cloud-status-dot"></div>
</div>
```

```css
.status-indicator {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 4px 8px;
    border-radius: 12px;
    background: rgba(255, 255, 255, 0.1);
}

.status-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #4CAF50; /* green for connected */
}

.status-dot.disconnected {
    background: #f44336; /* red for disconnected */
}
```

#### 3.2 Job Queue Display

```html
<!-- Add to studio dock -->
<div class="job-queue-panel" id="job-queue-panel">
    <h4>Active Jobs</h4>
    <div id="job-queue-list">
        <!-- Dynamic job list -->
    </div>
</div>
```

---

## Service-Specific Implementations

### RunPod Integration

**API Documentation:** https://docs.runpod.ai/

```javascript
// RunPod-specific workflow submission
async submitToRunPod(workflow, gpuType = 'RTX 3090') {
    const runpodWorkflow = {
        input: {
            workflow: workflow,
            gpu_type: gpuType
        }
    };
    
    const response = await fetch('https://api.runpod.ai/v2/runpod-worker-comfyui/runsync', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(runpodWorkflow)
    });
    
    return await response.json();
}
```

### Replicate Integration

**API Documentation:** https://replicate.com/docs

```javascript
// Replicate-specific image generation
async generateWithReplicate(prompt, negativePrompt, model = 'stability-ai/sdxl') {
    const response = await fetch(`https://api.replicate.com/v1/predictions`, {
        method: 'POST',
        headers: {
            'Authorization': `Token ${this.apiKey}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            version: model,
            input: {
                prompt: prompt,
                negative_prompt: negativePrompt,
                width: 512,
                height: 768,
                num_inference_steps: 30
            }
        })
    });
    
    const result = await response.json();
    
    // Poll for completion
    return await this.pollReplicateResult(result.urls.get);
}
```

---

## Migration Strategy

### Step 1: Add Cloud Configuration (Week 1)
- Add cloud service selection to settings
- Implement basic API key storage
- Test connection to cloud services

### Step 2: Update ComfyUI Integration (Week 2)
- Modify ComfyUIIntegration class for authentication
- Add service-specific API calls
- Test basic generation with cloud service

### Step 3: Add Advanced Features (Week 3)
- Implement job queue management
- Add billing tracking
- Create health monitoring

### Step 4: UI Enhancements (Week 4)
- Add connection status indicators
- Create job queue display
- Add service-specific settings

### Step 5: Testing & Optimization (Week 5)
- End-to-end testing with each service
- Performance optimization
- Error handling improvements

---

## Cost Optimization

### Strategies
1. **GPU Selection:** Choose appropriate GPU size for task
2. **Job Batching:** Combine multiple small jobs
3. **Caching:** Cache frequently used models
4. **Auto-scaling:** Scale down when idle

### Monitoring
```javascript
class CostMonitor {
    constructor() {
        this.costs = {
            runpod: { perMinute: 0.5 },
            replicate: { perRequest: 0.005 },
            together: { perToken: 0.0001 }
        };
    }

    estimateCost(service, params) {
        switch (service) {
            case 'runpod':
                return params.estimatedTime * this.costs.runpod.perMinute;
            case 'replicate':
                return this.costs.replicate.perRequest;
            case 'together':
                return params.tokenCount * this.costs.together.perToken;
        }
    }
}
```

---

## Security Considerations

### API Key Management
- Store API keys in secure localStorage with encryption
- Never log API keys in console
- Implement key rotation
- Use environment variables for server-side keys

### Data Privacy
- Encrypt sensitive data in transit
- Don't store prompts containing personal information
- Implement data retention policies

### Rate Limiting
- Implement client-side rate limiting
- Handle service rate limits gracefully
- Show user-friendly error messages

---

## Next Steps

1. **Choose Cloud Service:** Decide which service to integrate first
2. **Get API Access:** Obtain API keys for chosen service
3. **Implement Basic Connection:** Update ComfyUIIntegration class
4. **Test Generation:** Verify end-to-end workflow
5. **Add UI Controls:** Implement service selection in settings

Would you like me to implement the basic cloud connection for a specific service? Which cloud GPU service are you planning to use?</content>
<parameter name="filePath">c:\Users\samsc\OneDrive\Desktop\working protoype\docs\CLOUD_GPU_INTEGRATION.md