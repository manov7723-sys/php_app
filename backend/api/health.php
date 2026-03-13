<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once '../config/database.php';

try {
    $conn = getConnection();
    $conn->close();
    echo json_encode([
        'status'    => 'healthy',
        'message'   => 'API is running',
        'timestamp' => date('Y-m-d H:i:s'),
        'version'   => '1.0.0'
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status'  => 'unhealthy',
        'message' => $e->getMessage()
    ]);
}
?>
