# Deployment Guide

## Prerequisites

### **Google Cloud Platform Setup**
1. Create a new Google Cloud Project
2. Enable billing (required for some services, but stay within free tier)
3. Install Google Cloud SDK
4. Enable required APIs:
   ```bash
   gcloud services enable cloudfunctions.googleapis.com
   gcloud services enable run.googleapis.com
   gcloud services enable firestore.googleapis.com
   gcloud services enable storage-component.googleapis.com
   gcloud services enable aiplatform.googleapis.com
   ```

### **Development Environment**
```bash
# Required tools
python >= 3.9
pip >= 21.0
docker >= 20.10
gcloud CLI >= 400.0
```

### **API Keys & Credentials**
1. **Firebase Service Account**: Download JSON credentials
2. **Gemini API Key**: Get from Google AI Studio
3. **Project Configuration**: Note your project ID

## Project Setup

### **1. Clone and Configure**
```bash
# Clone the repository
git clone <your-repo-url>
cd multimedia-knowledge-backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### **2. Environment Configuration**
Create `.env` file in root directory:
```bash
# Google Cloud
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_APPLICATION_CREDENTIALS=path/to/firebase-credentials.json

# Firebase
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY_ID=your-private-key-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=your-service-account@your-project-id.iam.gserviceaccount.com
FIREBASE_CLIENT_ID=your-client-id
FIREBASE_AUTH_URI=https://accounts.google.com/o/oauth2/auth
FIREBASE_TOKEN_URI=https://oauth2.googleapis.com/token

# Gemini AI
GEMINI_API_KEY=your-gemini-api-key

# ChromaDB
CHROMA_URL=https://chroma-service-url.run.app
CHROMA_PERSIST_DIRECTORY=/chroma-data

# Security
JWT_SECRET=your-jwt-secret-key
API_KEY=your-api-key

# Environment
ENVIRONMENT=production
LOG_LEVEL=INFO
```

### **3. Initialize Firebase**
```bash
# Initialize Firestore
gcloud firestore databases create --region=us-central1

# Set up authentication
firebase init auth
firebase init firestore
```

## Deployment Steps

### **Step 1: Deploy ChromaDB Service**

#### **Build ChromaDB Container**
```bash
# Navigate to ChromaDB service directory
cd chroma_service

# Build Docker image
docker build -t gcr.io/YOUR_PROJECT_ID/chroma-service:latest .

# Push to Google Container Registry
docker push gcr.io/YOUR_PROJECT_ID/chroma-service:latest
```

#### **Deploy to Cloud Run**
```bash
gcloud run deploy chroma-service \
  --image gcr.io/YOUR_PROJECT_ID/chroma-service:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 1Gi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 2 \
  --set-env-vars CHROMA_PERSIST_DIRECTORY=/chroma-data \
  --set-env-vars GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID
```

#### **ChromaDB Dockerfile**
```dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

#### **ChromaDB Service Code**

### **Step 2: Deploy Cloud Functions**

#### **Note Processing Function**
```bash
cd cloud_functions/process_note

# Deploy function
gcloud functions deploy process-note \
  --runtime python39 \
  --trigger-event providers/cloud.firestore/eventTypes/document.write \
  --trigger-resource "projects/YOUR_PROJECT_ID/databases/(default)/documents/notes/{noteId}" \
  --set-env-vars GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID \
  --set-env-vars GEMINI_API_KEY=YOUR_GEMINI_API_KEY \
  --set-env-vars CHROMA_URL=https://chroma-service-url.run.app \
  --memory 512MB \
  --timeout 540s
```

#### **Recommendation Update Function**
```bash
cd cloud_functions/update_recommendations

# Deploy function
gcloud functions deploy update-recommendations \
  --runtime python39 \
  --trigger-event providers/cloud.firestore/eventTypes/document.write \
  --trigger-resource "projects/YOUR_PROJECT_ID/databases/(default)/documents/users/{userId}" \
  --set-env-vars GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID \
  --set-env-vars GEMINI_API_KEY=YOUR_GEMINI_API_KEY \
  --set-env-vars CHROMA_URL=https://chroma-service-url.run.app \
  --memory 256MB \
  --timeout 300s
```

### **Step 3: Deploy Main API Service**

#### **Build and Deploy FastAPI Service**
```bash
# Build Docker image for main API
docker build -t gcr.io/YOUR_PROJECT_ID/knowledge-api:latest .

# Push to Container Registry
docker push gcr.io/YOUR_PROJECT_ID/knowledge-api:latest

# Deploy to Cloud Run
gcloud run deploy knowledge-api \
  --image gcr.io/YOUR_PROJECT_ID/knowledge-api:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 1Gi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 10 \
  --set-env-vars GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID \
  --set-env-vars GEMINI_API_KEY=YOUR_GEMINI_API_KEY \
  --set-env-vars CHROMA_URL=https://chroma-service-url.run.app \
  --set-env-vars ENVIRONMENT=production
```

#### **Main API Dockerfile**
```dockerfile
FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose port
EXPOSE 8080

# Command to run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

### **Step 4: Configure Firestore Security Rules**

#### **Deploy Security Rules**
```bash
# Deploy Firestore rules
gcloud firestore rules deploy --rules-file=security/firestore.rules
```

*See [SECURITY.md](SECURITY.md) for the comprehensive Firestore security rules content.*

### **Step 5: Set Up Cloud Storage**

#### **Create Storage Buckets**
```bash
# Create bucket for media files
gsutil mb gs://YOUR_PROJECT_ID-media-files

# Create bucket for ChromaDB persistence
gsutil mb gs://YOUR_PROJECT_ID-chroma-data

# Set lifecycle policies
gsutil lifecycle set storage-lifecycle.json gs://YOUR_PROJECT_ID-media-files
```

#### **Storage Lifecycle Configuration**
```json
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "SetStorageClass",
          "storageClass": "COLDLINE"
        },
        "condition": {
          "age": 365
        }
      }
    ]
  }
}
```

## Configuration Files

## Testing Deployment

### **1. Health Checks**
```bash
# Test ChromaDB service
curl https://chroma-service-url.run.app/

# Test main API service
curl https://knowledge-api-url.run.app/docs

# Test Cloud Functions
gcloud functions call process-note --data '{}'
```

### **2. End-to-End Testing**
```python
# test_deployment.py
import requests
import json

def test_api_deployment():
    api_url = "https://knowledge-api-url.run.app"
    
    # Test health endpoint
    response = requests.get(f"{api_url}/")
    assert response.status_code == 200
    
    # Test authentication (requires valid token)
    headers = {"Authorization": "Bearer YOUR_TEST_TOKEN"}
    response = requests.get(f"{api_url}/api/users/profile", headers=headers)
    
    print(f"API Status: {response.status_code}")
    print(f"Response: {response.json()}")

if __name__ == "__main__":
    test_api_deployment()
```

## Monitoring Setup

### **1. Enable Logging**
```bash
# Enable Cloud Logging API
gcloud services enable logging.googleapis.com

# Create log-based metrics
gcloud logging metrics create api_errors \
  --description="API error count" \
  --log-filter='resource.type="cloud_run_revision" AND severity>=ERROR'
```

### **2. Set Up Alerting**
```bash
# Create notification channel
gcloud alpha monitoring channels create \
  --display-name="Email Alerts" \
  --type=email \
  --channel-labels=email_address=your-email@example.com

# Create alert policy
gcloud alpha monitoring policies create \
  --policy-from-file=alert-policy.json
```

### **3. Alert Policy Configuration**
```json
{
  "displayName": "API Error Rate Alert",
  "conditions": [
    {
      "displayName": "Error rate too high",
      "conditionThreshold": {
        "filter": "resource.type=\"cloud_run_revision\"",
        "comparison": "COMPARISON_GREATER_THAN",
        "thresholdValue": 0.1
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "1800s"
  }
}
```

## Maintenance & Updates

### **1. Rolling Updates**
```bash
# Update main API service
docker build -t gcr.io/YOUR_PROJECT_ID/knowledge-api:v2 .
docker push gcr.io/YOUR_PROJECT_ID/knowledge-api:v2

gcloud run deploy knowledge-api \
  --image gcr.io/YOUR_PROJECT_ID/knowledge-api:v2 \
  --platform managed \
  --region us-central1
```

### **2. Database Migrations**
```python
# scripts/migrate_data.py
from google.cloud import firestore
import os

def migrate_user_data():
    """Migrate user data to new schema"""
    db = firestore.Client()
    
    # Update user documents
    users_ref = db.collection('users')
    for user_doc in users_ref.stream():
        user_data = user_doc.to_dict()
        
        # Add new fields if missing
        if 'interests' not in user_data:
            user_data['interests'] = []
        
        # Update document
        user_doc.reference.update(user_data)
        print(f"Updated user: {user_doc.id}")

if __name__ == "__main__":
    migrate_user_data()
```

### **3. Backup Strategy**
```bash
# Create backup script
#!/bin/bash
# backup.sh

# Export Firestore data
gcloud firestore export gs://YOUR_PROJECT_ID-backups/$(date +%Y%m%d) \
  --collection-ids=users,notes,articles

# Backup ChromaDB data
gsutil -m cp -r gs://YOUR_PROJECT_ID-chroma-data gs://YOUR_PROJECT_ID-backups/chroma-$(date +%Y%m%d)

echo "Backup completed: $(date)"
```

## Troubleshooting

### **Common Issues**

#### **1. ChromaDB Connection Issues**
```bash
# Check ChromaDB service logs
gcloud logs read "resource.type=cloud_run_revision AND resource.labels.service_name=chroma-service" --limit=50

# Test connectivity
curl -v https://chroma-service-url.run.app/collections
```

#### **2. Cloud Function Timeouts**
```bash
# Check function logs
gcloud functions logs read process-note --limit=10

# Increase timeout
gcloud functions deploy process-note --timeout=540s
```

#### **3. Memory Issues**
```bash
# Monitor memory usage
gcloud monitoring metrics list --filter="resource.type=cloud_run_revision"

# Increase memory allocation
gcloud run deploy knowledge-api --memory=2Gi
```

### **Performance Optimization**

#### **1. Database Optimization**
```python
# Optimize Firestore queries
from google.cloud import firestore

def optimized_query():
    db = firestore.Client()
    
    # Use composite indexes
    query = db.collection('articles') \
        .where('user_id', '==', user_id) \
        .order_by('created_at', direction=firestore.Query.DESCENDING) \
        .limit(10)
    
    return list(query.stream())
```

#### **2. Caching Implementation**
```python
# Add caching layer
from functools import lru_cache
import time

@lru_cache(maxsize=128)
def get_user_recommendations(user_id: str, cache_key: str):
    """Cache recommendations for 10 minutes"""
    # Implementation here
    pass

# Use with time-based cache key
cache_key = str(int(time.time() // 600))  # 10-minute buckets
recommendations = get_user_recommendations(user_id, cache_key)
```

## Free Tier Monitoring

### **Track Usage**
```bash
# Monitor Cloud Run usage
gcloud run services list --platform=managed

# Check Firestore usage
gcloud alpha firestore databases describe --database="(default)"

# Monitor function invocations
gcloud functions describe process-note
```

### **Cost Optimization**
```python
# scripts/optimize_costs.py
def optimize_free_tier_usage():
    """Monitor and optimize free tier usage"""
    
    # Check daily limits
    firestore_reads = get_firestore_reads_today()
    function_invocations = get_function_invocations_today()
    
    if firestore_reads > 40000:  # 80% of free tier
        print("Warning: Approaching Firestore read limit")
    
    if function_invocations > 1600000:  # 80% of free tier
        print("Warning: Approaching function invocation limit")
```

Your multimedia knowledge management system is now ready for production deployment on Google Cloud Platform's free tier!