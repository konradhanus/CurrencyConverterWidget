<?php
header('Content-Type: application/json; charset=utf-8');

// ========================================== 
// KONFIGURACJA
// ========================================== 

define('TARGET_EMAIL', 'konrad.hanus@gmail.com');

define('SMTP_HOST', 'smtp.gmail.com');
define('SMTP_PORT', 587); 
define('SMTP_USER', 'im.alive.lumumu@gmail.com'); 
// UWAGA: Upewnij się, że poniższe hasło jest poprawne (App Password dla Gmaila)
define('SMTP_PASS', 'ssss');
 

// ========================================== 
// KLASA SMTP (Z poprawioną obsługą błędów)
// ========================================== 
class SimpleEmail {
    private $socket;
    private $log = [];

    public function send($to, $subject, $body) {
        try {
            $this->connect();
            $this->auth();
            
            $this->sendCommand('MAIL FROM: <' . SMTP_USER . '>', 250);
            $this->sendCommand('RCPT TO: <' . $to . '>', 250);
            $this->sendCommand('DATA', 354);
            
            $headers  = "MIME-Version: 1.0\r\n";
            $headers .= "Content-type: text/html; charset=UTF-8\r\n";
            $headers .= "From: Lumumu App <" . SMTP_USER . ">\r\n";
            $headers .= "To: $to\r\n";
            $headers .= "Subject: =?UTF-8?B?" . base64_encode($subject) . "?=\r\n";
            
            $message = "$headers\r\n$body\r\n.\r\n";
            $this->sendCommand($message, 250);
            
            $this->sendCommand('QUIT', 221);
            fclose($this->socket);
            return true;
        } catch (Exception $e) {
            if ($this->socket) fclose($this->socket);
            throw $e;
        }
    }

    private function connect() {
        $socket_context = stream_context_create(['ssl' => ['verify_peer' => false, 'verify_peer_name' => false]]);
        $this->socket = stream_socket_client('tcp://' . SMTP_HOST . ':' . SMTP_PORT, $errno, $errstr, 10, STREAM_CLIENT_CONNECT, $socket_context); 
        
        if (!$this->socket) {
            throw new Exception("Connection failed: $errno $errstr");
        }
        
        $this->readResponse(220);
        $this->sendCommand('EHLO ' . gethostname(), 250);
        $this->sendCommand('STARTTLS', 220);
        
        if (!stream_socket_enable_crypto($this->socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
            throw new Exception("TLS encryption failed");
        }
        
        $this->sendCommand('EHLO ' . gethostname(), 250);
    }

    private function auth() {
        $this->sendCommand('AUTH LOGIN', 334);
        $this->sendCommand(base64_encode(SMTP_USER), 334);
        $this->sendCommand(base64_encode(SMTP_PASS), 235);
    }

    private function sendCommand($cmd, $expectedCode = null) {
        if (!$this->socket) return; 
        
        fwrite($this->socket, $cmd . "\r\n");
        $response = $this->readResponse($expectedCode);
        
        return $response;
    }

    private function readResponse($expectedCode = null) {
        $response = "";
        while ($str = fgets($this->socket, 515)) {
            $response .= $str;
            if (substr($str, 3, 1) == " ") break;
        }
        
        if ($expectedCode) {
            $code = (int)substr($response, 0, 3);
            if ($code != $expectedCode) {
                throw new Exception("SMTP Error: Expected $expectedCode, got $code. Response: $response");
            }
        }
        
        return $response;
    }
}

// ========================================== 
// LOGIKA ENDPOINTU
// ========================================== 

// Obsługa CORS (jeśli potrzebna)
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
    exit;
}

$input = file_get_contents('php://input');
$data = json_decode($input, true);

if (!$data) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Invalid JSON']);
    exit;
}

$message = isset($data['message']) ? trim($data['message']) : '';
$userEmail = isset($data['email']) ? $data['email'] : 'Anonim';
$uid = isset($data['uid']) ? $data['uid'] : 'Brak UID';
$version = isset($data['version']) ? $data['version'] : 'Nieznana';

if (empty($message)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Wiadomość jest pusta']);
    exit;
}

$subject = "Lumumu Feedback: " . substr($message, 0, 30) . "...";
$body = "
    <h2>Nowe zgłoszenie z aplikacji</h2>
    <p><strong>Użytkownik:</strong> " . htmlspecialchars($userEmail) . "</p>
    <p><strong>UID:</strong> " . htmlspecialchars($uid) . "</p>
    <p><strong>Wersja App:</strong> " . htmlspecialchars($version) . "</p>
    <hr>
    <h3>Treść wiadomości:</h3>
    <p style='background-color: #f5f5f5; padding: 15px; border-left: 4px solid #008080;'>
        " . nl2br(htmlspecialchars($message)) . "
    </p>
";

try {
    $mailer = new SimpleEmail();
    $mailer->send(TARGET_EMAIL, $subject, $body);
    
    echo json_encode(['status' => 'success', 'message' => 'Feedback wysłany']);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error', 
        'message' => 'Błąd wysyłania: ' . $e->getMessage()
    ]);
}
?>
