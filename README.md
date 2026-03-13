# Task Manager - PHP Full Stack App

A full stack Task Manager application built with PHP backend and vanilla JS frontend.

## Project Structure

```
php-app/
├── frontend/
│   └── index.html          ← Frontend UI
├── backend/
│   ├── api/
│   │   ├── tasks.php       ← REST API endpoints
│   │   └── health.php      ← Health check endpoint
│   ├── config/
│   │   └── database.php    ← Database connection
│   ├── database.sql        ← Database setup
│   └── .htaccess           ← URL routing
└── README.md
```

## Setup Instructions

### Step 1 - Requirements
- PHP 7.4+
- MySQL 5.7+
- Apache with mod_rewrite enabled (XAMPP/WAMP/LAMP)

### Step 2 - Database Setup
```sql
mysql -u root -p < backend/database.sql
```

### Step 3 - Configure Database
Edit `backend/config/database.php`:
```php
define('DB_HOST', 'localhost');
define('DB_USER', 'your_username');
define('DB_PASS', 'your_password');
define('DB_NAME', 'task_manager');
```

### Step 4 - Configure Frontend API URL
Edit `frontend/index.html` line with `API_BASE`:
```javascript
const API_BASE = 'http://localhost/php-app/backend/api';
```

### Step 5 - Run
Place the project in your web server root (htdocs/www) and open:
```
http://localhost/php-app/frontend/index.html
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/tasks.php | Get all tasks |
| GET | /api/tasks.php?id=1 | Get single task |
| GET | /api/tasks.php?status=pending | Filter by status |
| POST | /api/tasks.php | Create task |
| PUT | /api/tasks.php?id=1 | Update task |
| DELETE | /api/tasks.php?id=1 | Delete task |
| GET | /api/health.php | Health check |

## Features
- ✅ Create, Read, Update, Delete tasks
- ✅ Filter by status (pending, in_progress, completed)
- ✅ Priority levels (low, medium, high)
- ✅ Real-time stats in navbar
- ✅ Responsive design
- ✅ REST API backend
ok 