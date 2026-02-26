# University Complaint Portal

A professional mobile application for university students to report various academic and behavioral issues. The portal provides a secure and anonymous way for students to submit complaints about faculty, teachers, harassment, and other academic concerns.

## Features

- **Roll Number Selection**: Users select from a predefined list of roll numbers (BSCSF23E01 to BSCSF23E05)
- **Complaint Types**: 10 predefined complaint categories
- **Image Attachments**: Ability to attach evidence photos (stored locally on device)
- **Real-time Submission**: Instant complaint submission to backend database
- **Status Tracking**: View all submitted complaints with status (Pending/Fixed)
- **Professional UI**: Clean blue/white themed interface
- **Responsive Design**: Works on all device sizes
- **Local Image Storage**: Images stored in device's local storage using shared preferences

## Tech Stack

### Frontend (Flutter)
- **Framework**: Flutter SDK 3.x
- **Language**: Dart
- **State Management**: setState for UI updates
- **HTTP Client**: http package for API communication
- **Image Handling**: image_picker for image selection
- **Local Storage**: shared_preferences for storing image paths
- **File Management**: path_provider for file operations

### Backend (PHP)
- **Language**: PHP 7.4+
- **Database**: MySQL
- **Framework**: Native PHP with PDO
- **API**: RESTful API endpoints
- **Security**: Prepared statements to prevent SQL injection

## Architecture

### Frontend Architecture
```
lib/
├── main.dart                 # App entry point
├── screens/
│   ├── roll_list_screen.dart # Roll number selection screen
│   ├── complaint_form.dart   # Main complaint submission form
│   └── thank_you.dart        # Thank you screen
├── services/
│   ├── api_service.dart      # API communication
│   ├── complaint_service.dart # Complaint data service
│   └── image_service.dart    # Image handling service
└── utils/
    └── constants.dart        # Application constants
```

### Backend Architecture
```
backend/
├── api/
│   ├── submit_complaint.php  # Submit new complaints
│   ├── get_complaint_status.php # Get complaint status by ID or roll number
│   └── test_connection.php   # Database connection test
├── config.php               # Database configuration
├── schema.sql               # Database schema
└── uploads/                 # Directory for storing images
```

## Database Schema

### Table: `complaints`
- `id`: INT (Primary Key, Auto Increment)
- `roll_number`: VARCHAR(20)
- `complaint_type`: VARCHAR(100)
- `description`: TEXT
- `created_at`: TIMESTAMP (Default: CURRENT_TIMESTAMP)

### Table: `complaint_details`
- `detail_id`: INT (Primary Key, Auto Increment)
- `complaint_id`: INT (Foreign Key to complaints.id)
- `user_id`: VARCHAR(20)
- `complaint_type_detail`: VARCHAR(100)
- `description_detail`: TEXT
- `status`: ENUM('Pending', 'In Progress', 'Resolved', 'Rejected') (Default: 'Pending')
- `assigned_to`: VARCHAR(100)
- `resolution_notes`: TEXT
- `created_at`: TIMESTAMP (Default: CURRENT_TIMESTAMP)
- `updated_at`: TIMESTAMP (Default: CURRENT_TIMESTAMP ON UPDATE)

## API Endpoints

### POST /api/submit_complaint.php
Submit a new complaint

**Request Body:**
```json
{
  "roll_number": "BSCSF23E01",
  "complaint_type": "Harassment Complaint",
  "description": "Detailed description of the complaint",
  "image_data": "base64_encoded_image_string",
  "image_name": "image_filename.jpg"
}
```

**Response:**
```json
{
  "message": "Complaint was submitted successfully.",
  "complaint_id": 123,
  "status": "success",
  "image_saved": true,
  "image_path": "uploads/complaint_image_123.jpg"
}
```

### GET /api/get_complaint_status.php
Get complaint status by ID or all complaints by roll number

**Query Parameters:**
- `complaint_id`: Get specific complaint by ID
- `roll_number`: Get all complaints for a roll number

**Response:**
```json
{
  "complaint_id": 123,
  "roll_number": "BSCSF23E01",
  "status": "Pending",
  "complaint_type": "Harassment Complaint",
  "description": "Detailed description of the complaint",
  "created_at": "2023-12-21 10:30:00",
  "image_path": "uploads/complaint_image_123.jpg"
}
```

## Installation & Setup

### Prerequisites
- Flutter SDK 3.x
- PHP 7.4+
- MySQL 5.7+
- Web server (Apache/Nginx)

### Frontend Setup
1. Clone the repository:
```bash
git clone <repository-url>
cd app1
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Backend Setup
1. Create the database:
```sql
CREATE DATABASE devxpert_complaints_master;
```

2. Import the schema:
```bash
mysql -u username -p devxpert_complaints_master < backend/schema.sql
```

3. Configure database connection in `backend/config.php`:
```php
$DB_HOST = 'localhost';
$DB_NAME = 'devxpert_complaints_master';
$DB_USER = 'devxpert_site';
$DB_PASS = 'qwertyuiop1234567890';
```

4. Ensure the `uploads` directory has write permissions:
```bash
chmod 755 backend/uploads/
```

## Complaint Categories

The app supports 10 predefined complaint types:
1. Faculty Behavior Issue
2. Teacher Misconduct
3. Harassment Complaint
4. Attendance Issue
5. Result / Marks Issue
6. Course Content Problem
7. Timetable / Scheduling Issue
8. Examination Issue
9. Fee / Accounts Problem
10. Other Academic Issue

## Image Handling

### Local Storage
- Images are stored in the device's local storage
- Image paths are saved using shared_preferences
- Images are converted to base64 for transmission
- Original file extensions are preserved

### Upload Process
1. User selects an image from gallery
2. Image is temporarily stored on device
3. On submission, image is converted to base64
4. Base64 data is sent to backend API
5. Backend saves image to server uploads directory
6. Image path is stored in database

## User Flow

1. **Roll Selection**: User selects from predefined roll numbers
2. **Complaint Form**: User selects complaint type, adds description, and optionally attaches image
3. **Submission**: Complaint is sent to backend with success indicator
4. **Tracking**: Submitted complaints appear in a list below the form
5. **Status Updates**: Complaint status is tracked as Pending/In Progress/Resolved

## Security Features

- **SQL Injection Prevention**: All database queries use prepared statements
- **CORS Configuration**: Proper CORS headers for secure API access
- **Input Validation**: Client and server-side validation
- **Secure Storage**: Images stored in private directories

## Error Handling

- Network error detection and user-friendly messages
- Proper timeout handling for API requests
- Image upload validation
- Form validation with clear error messages

## Deployment

### For Web
```bash
flutter build web
```

### For Mobile
```bash
flutter build apk --release
flutter build ios --release
```

## Testing

The application has been tested for:
- Form validation
- Image upload functionality
- Database connectivity
- Cross-platform compatibility
- Network error handling
- Local storage persistence

## Troubleshooting

### Common Issues
1. **Image Upload Fails**: Ensure the uploads directory exists with proper permissions
2. **API Connection Issues**: Check CORS configuration and API endpoint URLs
3. **Database Connection**: Verify database credentials in config.php

### Debugging
- Check browser console for web builds
- Use `flutter logs` for mobile debugging
- Enable PHP error logging for backend issues

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, please contact the development team at support@devxperts.site