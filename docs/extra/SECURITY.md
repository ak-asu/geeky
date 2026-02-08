# Security Guidelines

## Overview

This document outlines comprehensive security measures for the Multimedia Knowledge Management System. Security is implemented at multiple layers: authentication, authorization, data protection, network security, and operational security.

## Authentication & Authorization

### **Firebase Authentication Integration**

#### **User Authentication Flow**
```python
# api/auth.py
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth
import firebase_admin
from firebase_admin import credentials

# Initialize Firebase Admin SDK
cred = credentials.Certificate("path/to/serviceAccountKey.json")
firebase_admin.initialize_app(cred)

security = HTTPBearer()

async def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Verify Firebase ID token"""
    try:
        # Verify the ID token
        decoded_token = auth.verify_id_token(credentials.credentials)
        return decoded_token
    except Exception as e:
        raise HTTPException(
            status_code=401,
            detail="Invalid authentication token"
        )

async def get_current_user(token: dict = Depends(verify_token)):
    """Get current authenticated user"""
    return {
        "uid": token["uid"],
        "email": token.get("email"),
        "email_verified": token.get("email_verified", False)
    }
```

#### **Role-Based Access Control**
```python
# models.py
from enum import Enum
from typing import List

class UserRole(str, Enum):
    USER = "user"
    PREMIUM = "premium"
    ADMIN = "admin"

class Permission(str, Enum):
    READ_NOTES = "read:notes"
    WRITE_NOTES = "write:notes"
    DELETE_NOTES = "delete:notes"
    READ_ARTICLES = "read:articles"
    ADMIN_ACCESS = "admin:access"

ROLE_PERMISSIONS = {
    UserRole.USER: [
        Permission.READ_NOTES,
        Permission.WRITE_NOTES,
        Permission.READ_ARTICLES
    ],
    UserRole.PREMIUM: [
        Permission.READ_NOTES,
        Permission.WRITE_NOTES,
        Permission.DELETE_NOTES,
        Permission.READ_ARTICLES
    ],
    UserRole.ADMIN: [
        Permission.READ_NOTES,
        Permission.WRITE_NOTES,
        Permission.DELETE_NOTES,
        Permission.READ_ARTICLES,
        Permission.ADMIN_ACCESS
    ]
}

def check_permission(user_role: UserRole, required_permission: Permission) -> bool:
    """Check if user role has required permission"""
    return required_permission in ROLE_PERMISSIONS.get(user_role, [])
```

### **API Key Management**

## Data Protection

### **Encryption at Rest**

#### **Firestore Encryption**

#### **File Encryption for Cloud Storage**
```python
# services/storage.py
from google.cloud import storage
from cryptography.fernet import Fernet
import os
import tempfile

class EncryptedStorageService:
    def __init__(self):
        self.client = storage.Client()
        self.bucket_name = os.getenv("STORAGE_BUCKET")
        self.encryption_key = os.getenv("FILE_ENCRYPTION_KEY")
        self.cipher_suite = Fernet(self.encryption_key.encode()) if self.encryption_key else None
    
    def upload_encrypted_file(self, file_data: bytes, filename: str) -> str:
        """Upload encrypted file to Cloud Storage"""
        if self.cipher_suite:
            encrypted_data = self.cipher_suite.encrypt(file_data)
        else:
            encrypted_data = file_data
        
        bucket = self.client.bucket(self.bucket_name)
        blob = bucket.blob(filename)
        blob.upload_from_string(encrypted_data)
        
        return f"gs://{self.bucket_name}/{filename}"
    
    def download_encrypted_file(self, filename: str) -> bytes:
        """Download and decrypt file from Cloud Storage"""
        bucket = self.client.bucket(self.bucket_name)
        blob = bucket.blob(filename)
        encrypted_data = blob.download_as_bytes()
        
        if self.cipher_suite:
            return self.cipher_suite.decrypt(encrypted_data)
        else:
            return encrypted_data
```

### **Data Sanitization**

## Network Security

### **HTTPS and TLS Configuration**

### **Rate Limiting**

### **Input Validation**

## Firestore Security Rules

### **Comprehensive Security Rules**
```javascript
// security/firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    function isValidUser(data) {
      return data.keys().hasAll(['email', 'created_at']) &&
             data.email is string &&
             data.email.matches('.*@.*\\..*') &&
             data.created_at is timestamp;
    }
    
    function isValidNote(data) {
      return data.keys().hasAll(['user_id', 'title', 'content', 'created_at']) &&
             data.user_id is string &&
             data.title is string &&
             data.title.size() <= 200 &&
             data.content is string &&
             data.content.size() <= 100000 &&
             data.created_at is timestamp;
    }
    
    function isValidArticle(data) {
      return data.keys().hasAll(['user_id', 'summary', 'created_at']) &&
             data.user_id is string &&
             data.summary is string &&
             data.summary.size() <= 10000 &&
             data.created_at is timestamp;
    }
    
    // User documents
    match /users/{userId} {
      allow read: if isAuthenticated() && isOwner(userId);
      allow create: if isAuthenticated() && isOwner(userId) && isValidUser(request.resource.data);
      allow update: if isAuthenticated() && isOwner(userId) && isValidUser(request.resource.data);
      allow delete: if isAuthenticated() && isOwner(userId);
    }
    
    // Note documents
    match /notes/{noteId} {
      allow read: if isAuthenticated() && isOwner(resource.data.user_id);
      allow create: if isAuthenticated() && 
                   isOwner(request.resource.data.user_id) && 
                   isValidNote(request.resource.data);
      allow update: if isAuthenticated() && 
                   isOwner(resource.data.user_id) && 
                   isValidNote(request.resource.data);
      allow delete: if isAuthenticated() && isOwner(resource.data.user_id);
    }