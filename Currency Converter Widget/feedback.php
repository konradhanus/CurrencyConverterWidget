<?php
header('Content-Type: application/json; charset=utf-8');

// ========================================== 
// KONFIGURACJA
// ========================================== 

// Twój email docelowy
define('TARGET_EMAIL', 'konrad.hanus@gmail.com');

define('SMTP_HOST', 'smtp.gmail.com');
define('SMTP_PORT', 587); 
define('SMTP_USER', 'im.alive.lumumu@gmail.com'); 
define('SMTP_PASS', 'ssss');
 

// ========================================== 
// KLASA SMTP (Skopiowana z Twojego server.php)
// ========================================== 
class SimpleEmail {
    private $socket;

    public function send($to, $subject, $body) {
        $this->connect();
        $this->auth();
        $this->sendCommand('MAIL FROM: <' . SMTP_USER . '>');
        $this->sendCommand('RCPT TO: <' . $to . '>');
        $this->sendCommand('DATA');
        $headers  = "MIME-Version: 1.0\r\n";
        $headers .= "Content-type: text/html; charset=UTF-8\r\n";
        $headers .= "From: Lumumu App <" . SMTP_USER . ">\r\n";
        $headers .= "To: $to\r\n";
        $headers .= "Subject: $subject\r\n";
        $message = "$headers\r\n$body\r\n.\r\n";
        $this->sendCommand($message);
        $this->sendCommand('QUIT');
        fclose($this->socket);
    }

    private function connect() {
        $socket_context = stream_context_create(['ssl' => ['verify_peer' => false, 'verify_peer_name' => false]]);
        $this->socket = stream_socket_client('tcp://' . SMTP_HOST . ':' . SMTP_PORT, $errno, $errstr, 15, STREAM_CLIENT_CONNECT, $socket_context);
        if (!$this->socket) return; 
        $this->readResponse();
        $this->sendCommand('EHLO ' . gethostname());
        $this->sendCommand('STARTTLS');
        stream_socket_enable_crypto($this->socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT);
        $this->sendCommand('EHLO ' . gethostname());
    }

    private function auth() {
        $this->sendCommand('AUTH LOGIN');
        $this->sendCommand(base64_encode(SMTP_USER));
        $this->sendCommand(base64_encode(SMTP_PASS));
    }

    private function sendCommand($cmd) {
        if ($this->socket) {
            fwrite($this->socket, $cmd . "\r\n");
            $this->readResponse();
        }
    }

    private function readResponse() {
        $response = "";
        if ($this->socket) {
            while ($str = fgets($this->socket, 515)) {
                $response .= $str;
                if (substr($str, 3, 1) == " ") break;
            }
        }
        return $response;
    }
}

// ========================================== 
// LOGIKA ENDPOINTU
// ========================================== 

// Sprawdź czy to POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
    exit;
}

// Pobierz dane JSON z ciała żądania
$input = file_get_contents('php://input');
$data = json_decode($input, true);

// Walidacja
$message = isset($data['message']) ? trim($data['message']) : '';
$userEmail = isset($data['email']) ? $data['email'] : 'Anonim';
$uid = isset($data['uid']) ? $data['uid'] : 'Brak UID';
$version = isset($data['version']) ? $data['version'] : 'Nieznana';

if (empty($message)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Wiadomość jest pusta']);
    exit;
}

// Przygotowanie treści maila
$subject = "Lumumu Feedback od: $userEmail";
$body = "
    <h2>Nowe zgłoszenie z aplikacji</h2>
    <p><strong>Użytkownik:</strong> $userEmail</p>
    <p><strong>UID:</strong> $uid</p>
    <p><strong>Wersja App:</strong> $version</p>
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
    echo json_encode(['status' => 'error', 'message' => 'Błąd wysyłania: ' . $e->getMessage()]);
}
?>
