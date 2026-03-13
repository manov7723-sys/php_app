<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once '../config/database.php';

$method = $_SERVER['REQUEST_METHOD'];
$path   = isset($_GET['path']) ? $_GET['path'] : '';
$id     = isset($_GET['id']) ? (int)$_GET['id'] : null;

switch ($method) {
    case 'GET':
        if ($id) {
            getTask($id);
        } else {
            getTasks();
        }
        break;
    case 'POST':
        createTask();
        break;
    case 'PUT':
        if ($id) updateTask($id);
        break;
    case 'DELETE':
        if ($id) deleteTask($id);
        break;
    default:
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
}

function getTasks() {
    $conn   = getConnection();
    $status = isset($_GET['status']) ? $_GET['status'] : '';
    
    if ($status) {
        $stmt = $conn->prepare("SELECT * FROM tasks WHERE status = ? ORDER BY created_at DESC");
        $stmt->bind_param("s", $status);
    } else {
        $stmt = $conn->prepare("SELECT * FROM tasks ORDER BY created_at DESC");
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    $tasks  = [];
    
    while ($row = $result->fetch_assoc()) {
        $tasks[] = $row;
    }
    
    echo json_encode(['success' => true, 'data' => $tasks, 'count' => count($tasks)]);
    $conn->close();
}

function getTask($id) {
    $conn = getConnection();
    $stmt = $conn->prepare("SELECT * FROM tasks WHERE id = ?");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($task = $result->fetch_assoc()) {
        echo json_encode(['success' => true, 'data' => $task]);
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'Task not found']);
    }
    $conn->close();
}

function createTask() {
    $conn  = getConnection();
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (empty($input['title'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Title is required']);
        return;
    }
    
    $title       = $input['title'];
    $description = isset($input['description']) ? $input['description'] : '';
    $status      = isset($input['status']) ? $input['status'] : 'pending';
    $priority    = isset($input['priority']) ? $input['priority'] : 'medium';
    
    $stmt = $conn->prepare("INSERT INTO tasks (title, description, status, priority) VALUES (?, ?, ?, ?)");
    $stmt->bind_param("ssss", $title, $description, $status, $priority);
    
    if ($stmt->execute()) {
        http_response_code(201);
        echo json_encode(['success' => true, 'message' => 'Task created', 'id' => $conn->insert_id]);
    } else {
        http_response_code(500);
        echo json_encode(['error' => 'Failed to create task']);
    }
    $conn->close();
}

function updateTask($id) {
    $conn  = getConnection();
    $input = json_decode(file_get_contents('php://input'), true);
    
    $title       = isset($input['title']) ? $input['title'] : null;
    $description = isset($input['description']) ? $input['description'] : null;
    $status      = isset($input['status']) ? $input['status'] : null;
    $priority    = isset($input['priority']) ? $input['priority'] : null;
    
    $stmt = $conn->prepare("UPDATE tasks SET title=COALESCE(?,title), description=COALESCE(?,description), status=COALESCE(?,status), priority=COALESCE(?,priority) WHERE id=?");
    $stmt->bind_param("ssssi", $title, $description, $status, $priority, $id);
    
    if ($stmt->execute() && $stmt->affected_rows > 0) {
        echo json_encode(['success' => true, 'message' => 'Task updated']);
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'Task not found or no changes made']);
    }
    $conn->close();
}

function deleteTask($id) {
    $conn = getConnection();
    $stmt = $conn->prepare("DELETE FROM tasks WHERE id = ?");
    $stmt->bind_param("i", $id);
    
    if ($stmt->execute() && $stmt->affected_rows > 0) {
        echo json_encode(['success' => true, 'message' => 'Task deleted']);
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'Task not found']);
    }
    $conn->close();
}
?>
