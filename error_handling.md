# Error Handling API Documentation

## Overview
The Error Handling API manages predefined error codes and driver document review processes. It provides endpoints for admins to review driver documents, assign errors, and for drivers to view their assigned errors.

## Base URL
```
https://api.cabapp.com/api/v1/errors
```

## Error Code Categories

### Document Errors (1000-1999)
- **1001**: Driving licence is blurry or unclear
- **1002**: Driving licence has expired
- **1003**: Driving licence information doesn't match profile
- **1004**: Aadhar card is blurry or unclear
- **1005**: Aadhar card information doesn't match profile
- **1006**: Profile photo is not clear
- **1007**: RC book is blurry or unclear
- **1008**: RC book has expired
- **1009**: FC certificate is blurry or unclear
- **1010**: FC certificate has expired
- **1011**: Vehicle photos are not clear
- **1012**: Wrong document uploaded

### Profile Errors (2000-2999)
- **2001**: Phone number verification required
- **2002**: Email verification required
- **2003**: Complete profile information required

### Vehicle Errors (3000-3999)
- **3001**: Vehicle registration number mismatch
- **3002**: Vehicle type not supported
- **3003**: Vehicle condition not acceptable

---

## API Endpoints

### 1. Get All Error Logs
```http
GET /api/v1/errors
```

**Description**: Retrieve all error logs with pagination

**Query Parameters**:
- `skip` (int, optional): Number of records to skip (default: 0)
- `limit` (int, optional): Maximum records to return (default: 100)

**Response**:
```json
[
  {
    "error_id": "uuid-string",
    "error_code": 1001,
    "error_type": "DOCUMENT",
    "error_description": "Driving licence is blurry or unclear",
    "admin_description": "The uploaded driving license image is not clear enough for verification."
  }
]
```

---

### 2. Get Predefined Errors
```http
GET /api/v1/errors/predefined-errors
```

**Description**: Get all predefined errors for admin checkbox selection

**Response**:
```json
{
  "errors": [
    {
      "error_code": 1001,
      "error_type": "DOCUMENT",
      "error_description": "Driving licence is blurry or unclear"
    },
    {
      "error_code": 1002,
      "error_type": "DOCUMENT", 
      "error_description": "Driving licence has expired"
    }
  ]
}
```

---

### 3. Get Error by ID
```http
GET /api/v1/errors/{error_id}
```

**Description**: Get specific error log by ID

**Path Parameters**:
- `error_id` (string): UUID of the error log

**Response**:
```json
{
  "error_id": "uuid-string",
  "error_code": 1001,
  "error_type": "DOCUMENT",
  "error_description": "Driving licence is blurry or unclear",
  "admin_description": "The uploaded driving license image is not clear enough for verification."
}
```

---

### 4. Create Error Log
```http
POST /api/v1/errors
```

**Description**: Create a new error log (Admin only)

**Request Body**:
```json
{
  "error_code": 4001,
  "error_type": "CUSTOM",
  "error_description": "Custom error description",
  "admin_description": "Detailed admin description"
}
```

**Response**:
```json
{
  "error_id": "generated-uuid",
  "error_code": 4001,
  "error_type": "CUSTOM",
  "error_description": "Custom error description",
  "admin_description": "Detailed admin description"
}
```

---

### 5. Review Driver Documents
```http
POST /api/v1/errors/review-driver-documents
```

**Description**: Admin reviews driver documents and approves/rejects with error assignment

**Request Body**:
```json
{
  "driver_id": "driver-uuid",
  "action": "reject",
  "selected_error_codes": [1001, 1007, 1011]
}
```

**Actions**:
- `"approve"`: Approves driver and clears errors
- `"reject"`: Rejects driver and assigns selected errors

**Response (Approve)**:
```json
{
  "message": "Driver John Doe approved successfully",
  "driver_id": "driver-uuid",
  "status": "approved"
}
```

**Response (Reject)**:
```json
{
  "message": "Driver John Doe registration rejected",
  "driver_id": "driver-uuid",
  "status": "rejected",
  "errors_assigned": 3,
  "assigned_error_codes": [1001, 1007, 1011],
  "driver_errors": {
    "error_codes": [1001, 1007, 1011],
    "details": {
      "1001": {
        "error_type": "DOCUMENT",
        "error_description": "Driving licence is blurry or unclear",
        "assigned_at": "2024-01-15T10:30:00",
        "status": "pending"
      }
    }
  }
}
```

---

### 6. Assign Errors to Driver
```http
POST /api/v1/errors/assign-errors-to-driver
```

**Description**: Admin assigns predefined errors to driver

**Request Body**:
```json
{
  "driver_id": "driver-uuid",
  "error_codes": [1001, 1004, 2001]
}
```

**Response**:
```json
{
  "message": "Assigned 3 errors to driver John Doe",
  "driver_id": "driver-uuid",
  "assigned_errors": [1001, 1004, 2001],
  "driver_errors": {
    "error_codes": [1001, 1004, 2001],
    "details": {
      "1001": {
        "error_type": "DOCUMENT",
        "error_description": "Driving licence is blurry or unclear",
        "assigned_at": "2024-01-15T10:30:00",
        "status": "pending"
      }
    }
  }
}
```

---

### 7. Get Driver Errors
```http
GET /api/v1/errors/driver/{driver_id}
```

**Description**: Get all errors assigned to a specific driver (for driver app)

**Path Parameters**:
- `driver_id` (string): UUID of the driver

**Response (With Errors)**:
```json
{
  "driver_id": "driver-uuid",
  "driver_name": "John Doe",
  "has_errors": true,
  "error_count": 2,
  "errors": [
    {
      "error_code": 1001,
      "error_type": "DOCUMENT",
      "error_description": "Driving licence is blurry or unclear",
      "assigned_at": "2024-01-15T10:30:00",
      "status": "pending"
    },
    {
      "error_code": 1007,
      "error_type": "DOCUMENT",
      "error_description": "RC book is blurry or unclear",
      "assigned_at": "2024-01-15T10:30:00",
      "status": "pending"
    }
  ],
  "message": "Please fix the document issues and re-upload"
}
```

**Response (No Errors)**:
```json
{
  "driver_id": "driver-uuid",
  "driver_name": "John Doe",
  "has_errors": false,
  "errors": [],
  "message": "No errors found"
}
```

---

### 8. Remove Error from Driver
```http
DELETE /api/v1/errors/remove-from-driver
```

**Description**: Admin removes specific error from driver

**Request Body**:
```json
{
  "driver_id": "driver-uuid",
  "error_code": 1001
}
```

**Response**:
```json
{
  "message": "Error 1001 removed from driver driver-uuid",
  "remaining_errors": 2
}
```

---

### 9. Delete Error Log
```http
DELETE /api/v1/errors/{error_id}
```

**Description**: Delete an error log (Admin only)

**Path Parameters**:
- `error_id` (string): UUID of the error log

**Response**:
```json
{
  "message": "Error log deleted successfully",
  "error_id": "error-uuid"
}
```

---

## Error Responses

### 400 Bad Request
```json
{
  "detail": "Error codes required for rejection"
}
```

### 404 Not Found
```json
{
  "detail": "Driver not found"
}
```

### 500 Internal Server Error
```json
{
  "detail": "Internal server error: Database connection failed"
}
```

---

## Usage Examples

### Admin Workflow: Review Driver Documents

1. **Get predefined errors for checkboxes**:
```bash
curl -X GET "https://api.cabapp.com/api/v1/errors/predefined-errors"
```

2. **Review and reject driver with selected errors**:
```bash
curl -X POST "https://api.cabapp.com/api/v1/errors/review-driver-documents" \
  -H "Content-Type: application/json" \
  -d '{
    "driver_id": "driver-uuid",
    "action": "reject",
    "selected_error_codes": [1001, 1007, 1011]
  }'
```

3. **Approve driver after corrections**:
```bash
curl -X POST "https://api.cabapp.com/api/v1/errors/review-driver-documents" \
  -H "Content-Type: application/json" \
  -d '{
    "driver_id": "driver-uuid",
    "action": "approve"
  }'
```

### Driver App: Check Assigned Errors

```bash
curl -X GET "https://api.cabapp.com/api/v1/errors/driver/driver-uuid"
```

---

## Business Logic

### Error Assignment Rules
- Drivers are automatically marked as `is_approved = false` when errors are assigned
- Multiple errors can be assigned simultaneously
- Errors are stored in driver's `errors` JSON field with timestamps
- Each error has a status: `"pending"` (default)

### Document Review Process
1. Admin reviews driver documents
2. If issues found, admin selects relevant error codes from predefined list
3. System assigns errors to driver and marks as not approved
4. Driver receives error details via API
5. Driver fixes issues and re-uploads documents
6. Admin reviews again and approves if satisfactory

### Error Categories
- **DOCUMENT**: Issues with uploaded documents (licence, aadhar, RC, etc.)
- **PROFILE**: Profile completion or verification issues
- **VEHICLE**: Vehicle-related problems

---

## Security Notes

- All admin endpoints should be protected with proper authentication
- Driver error viewing is restricted to the specific driver
- Error codes are predefined to prevent arbitrary error creation
- All database operations are wrapped in try-catch for error handling

---

## Related APIs

- **[Drivers API](drivers.md)** - Driver management and approval status
- **[Vehicles API](vehicles.md)** - Vehicle document verification