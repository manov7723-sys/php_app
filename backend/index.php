<?php
header('Content-Type: application/json');
echo json_encode([
    'message' => 'PHP Task Manager API',
    'version' => '1.0.0',
    'endpoints' => [
        'GET /api/tasks.php'        => 'Get all tasks',
        'POST /api/tasks.php'       => 'Create task',
        'PUT /api/tasks.php?id=1'   => 'Update task',
        'DELETE /api/tasks.php?id=1'=> 'Delete task',
        'GET /api/health.php'       => 'Health check'
    ]
]);