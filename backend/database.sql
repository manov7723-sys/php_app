-- Task Manager Database Setup
CREATE DATABASE IF NOT EXISTS task_manager;
USE task_manager;

CREATE TABLE IF NOT EXISTS tasks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status ENUM('pending', 'in_progress', 'completed') DEFAULT 'pending',
    priority ENUM('low', 'medium', 'high') DEFAULT 'medium',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Sample data
INSERT INTO tasks (title, description, status, priority) VALUES
('Setup project', 'Initialize the project structure', 'completed', 'high'),
('Design database', 'Create database schema', 'completed', 'high'),
('Build API', 'Create REST API endpoints', 'in_progress', 'high'),
('Build Frontend', 'Create user interface', 'in_progress', 'medium'),
('Write tests', 'Add unit and integration tests', 'pending', 'low');
