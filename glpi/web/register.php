<?php
function requestIsHttps(): bool {
    return !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';
}

$requestIsHttps = requestIsHttps();
session_set_cookie_params([
    'httponly' => true,
    'secure'   => $requestIsHttps,
    'samesite' => 'Lax',
]);
session_start();

// Registration URLs may contain a short-lived token. Do not cache or forward it.
header('Cache-Control: no-store, max-age=0');
header('Pragma: no-cache');
header('Referrer-Policy: no-referrer');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header("Content-Security-Policy: default-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self'; script-src 'self' 'unsafe-inline'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'");

// ============================================================
// Error Logging Setup
// ============================================================
$logDir = getenv('GLPI_REGISTER_LOG_DIR') ?: dirname(__DIR__, 2) . '/var/log/glpi-registration';
if (!is_dir($logDir)) { mkdir($logDir, 0750, true); }
ini_set('error_log', $logDir . '/register_' . date('Y-m') . '.log');
ini_set('log_errors', '1');

function logEvent(string $level, string $msg, array $ctx = []): void {
    $line = sprintf("[%s] [%s] [%s] %s %s",
        date('Y-m-d H:i:s'),
        $level,
        $_SERVER['REMOTE_ADDR'] ?? '-',
        $msg,
        $ctx ? json_encode($ctx, JSON_UNESCAPED_UNICODE) : ''
    );
    error_log(trim($line));
}

// ============================================================
// Rate Limiting (file-based, 5 requests per 10 minutes per IP)
// ============================================================
function checkRateLimit(string $ip, int $maxAttempts = 5, int $windowSec = 600): bool {
    global $logDir;
    $dir = $logDir . '/ratelimit';
    if (!is_dir($dir)) { mkdir($dir, 0750, true); }
    $file = $dir . '/' . md5($ip) . '.json';
    $now  = time();
    $attempts = [];
    if (file_exists($file)) {
        $attempts = json_decode(file_get_contents($file), true) ?: [];
        $attempts = array_filter($attempts, fn($t) => ($now - $t) < $windowSec);
    }
    if (count($attempts) >= $maxAttempts) { return false; }
    $attempts[] = $now;
    file_put_contents($file, json_encode(array_values($attempts)), LOCK_EX);
    return true;
}

// ============================================================
// CSRF Protection
// ============================================================
if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

// ============================================================
// อ่าน config จาก glpi_config.ini
// ============================================================
$iniPath = getenv('GLPI_CONFIG_PATH') ?: dirname(__DIR__) . '/glpi_config.ini';
if (!file_exists($iniPath)) {
    http_response_code(500);
    die('Configuration file not found. Contact IT administrator.');
}
$ini = parse_ini_file($iniPath, true);
if (!$ini || empty($ini['GLPI']['SERVER_URL']) || empty($ini['GLPI']['USER_TOKEN'])) {
    http_response_code(500);
    die('Invalid configuration. Contact IT administrator.');
}
$cfg = [
    'glpiUrl'   => rtrim($ini['GLPI']['SERVER_URL'], '/'),
    'userToken' => $ini['GLPI']['USER_TOKEN'],
    'tokens'    => $ini['APP_TOKENS'] ?? [],
    'networks'  => $ini['NETWORKS'] ?? [],
    'allowedSubnets' => array_filter(array_map('trim', explode(',', $ini['REGISTRATION']['ALLOWED_SUBNETS'] ?? ''))),
    'allowUserCreation' => filter_var($ini['REGISTRATION']['ALLOW_USER_CREATION'] ?? false, FILTER_VALIDATE_BOOLEAN),
    'publicBaseUrl' => rtrim(trim($ini['REGISTRATION']['PUBLIC_BASE_URL'] ?? ''), '/'),
    'requireRegistrationToken' => filter_var($ini['REGISTRATION']['REQUIRE_REGISTRATION_TOKEN'] ?? false, FILTER_VALIDATE_BOOLEAN),
    'registrationTokenSecret' => $ini['REGISTRATION']['REGISTRATION_TOKEN_SECRET'] ?? '',
    'tokenTtlSeconds' => max(60, min(86400, (int)($ini['REGISTRATION']['TOKEN_TTL_SECONDS'] ?? 900))),
    'defaultComputerStateId' => max(1, (int)($ini['REGISTRATION']['DEFAULT_COMPUTER_STATE_ID'] ?? 1)),
    'assetNumberField' => trim($ini['REGISTRATION']['ASSET_NUMBER_FIELD'] ?? 'otherserial'),
    'requireHttpsForGlpi' => filter_var($ini['REGISTRATION']['REQUIRE_HTTPS_FOR_GLPI'] ?? false, FILTER_VALIDATE_BOOLEAN),
];

$glpiUrl   = $cfg['glpiUrl'];
$userToken = $cfg['userToken'];

if ($cfg['publicBaseUrl'] !== '' && (!filter_var($cfg['publicBaseUrl'], FILTER_VALIDATE_URL) || parse_url($cfg['publicBaseUrl'], PHP_URL_SCHEME) !== 'https')) {
    http_response_code(500);
    die('Invalid PUBLIC_BASE_URL configuration.');
}
if ($cfg['requireRegistrationToken'] && strlen($cfg['registrationTokenSecret']) < 32) {
    http_response_code(500);
    die('Invalid registration-token configuration.');
}
if (!preg_match('/^[a-z_][a-z0-9_]*$/', $cfg['assetNumberField'])) {
    http_response_code(500);
    die('Invalid asset-number field configuration.');
}
if ($cfg['requireHttpsForGlpi'] && parse_url($glpiUrl, PHP_URL_SCHEME) !== 'https') {
    http_response_code(500);
    die('GLPI API must use HTTPS.');
}

// Never build a redirect from the untrusted Host header. Configure PUBLIC_BASE_URL instead.
if (!$requestIsHttps && !in_array($_SERVER['REMOTE_ADDR'] ?? '', ['127.0.0.1', '::1'], true)) {
    if ($cfg['publicBaseUrl'] === '') {
        http_response_code(400);
        die('HTTPS is required. Contact IT administrator.');
    }
    $query = [];
    foreach (['hn', 'rt'] as $key) {
        if (isset($_GET[$key]) && is_string($_GET[$key])) $query[$key] = $_GET[$key];
    }
    header('Location: ' . $cfg['publicBaseUrl'] . ($query ? '?' . http_build_query($query, '', '&', PHP_QUERY_RFC3986) : ''), true, 302);
    exit;
}

// ============================================================
$departments = [
    "IT"        => [],
    "SH"        => [],
    "MM"        => [],
    "QA"        => [],
    "HR"        => [],
    "AC"        => [],
    "CP"        => [],
    "Sr. Mgt"   => [],
    "RD"        => [],
    "SCM"       => ["PU","OS","EX","WH"],
    "Operation" => ["PE","PD1","PD2","PD3","EN","PC"],
    "BD&CS"     => ["CS","BD","EC"],
];

function isIpInCidr(string $ip, string $cidr): bool {
    if (!str_contains($cidr, '/')) return hash_equals($cidr, $ip);
    [$network, $bits] = explode('/', $cidr, 2);
    if (!filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) || !filter_var($network, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) return false;
    $bits = (int)$bits;
    if ($bits < 0 || $bits > 32) return false;
    $mask = $bits === 0 ? 0 : (-1 << (32 - $bits));
    return ((ip2long($ip) & $mask) === (ip2long($network) & $mask));
}

function isAllowedClient(string $ip): bool {
    global $cfg;
    foreach ($cfg['allowedSubnets'] as $cidr) {
        if (isIpInCidr($ip, $cidr)) return true;
    }
    return false;
}

function getAppToken($ip) {
    global $cfg;
    foreach ($cfg['networks'] as $tokenName => $cidr) {
        $token = $cfg['tokens'][$tokenName] ?? '';
        if ($token !== '' && isIpInCidr($ip, $cidr)) return $token;
    }
    return null;
}

function isValidHostname(string $hostname): bool {
    return (bool)preg_match('/^[A-Z0-9][A-Z0-9-]{0,62}$/', $hostname);
}

function base64UrlEncode(string $value): string {
    return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
}

function verifyRegistrationToken(string $token, string $hostname, string $lark): bool {
    global $cfg;
    if (!$cfg['requireRegistrationToken']) return true;
    if (!preg_match('/^v1\.([0-9]{10})\.([A-Za-z0-9_-]{16,64})\.([A-Za-z0-9_-]{43})$/', $token, $parts)) return false;

    [, $expires, $nonce, $signature] = $parts;
    $expiry = (int)$expires;
    if ($expiry < time() || $expiry > time() + $cfg['tokenTtlSeconds']) return false;

    // The signature binds the link to both the expected device and Lark account.
    $expected = base64UrlEncode(hash_hmac('sha256', "$hostname|$lark|$expires|$nonce", $cfg['registrationTokenSecret'], true));
    return hash_equals($expected, $signature);
}

function consumeRegistrationToken(string $token): bool {
    global $cfg, $logDir;
    if (!$cfg['requireRegistrationToken']) return true;
    $dir = $logDir . '/used-registration-tokens';
    if (!is_dir($dir) && !mkdir($dir, 0750, true) && !is_dir($dir)) return false;
    $file = $dir . '/' . hash('sha256', $token);
    $handle = @fopen($file, 'x');
    if ($handle === false) return false;
    fwrite($handle, (string)time());
    fclose($handle);
    return true;
}

// ============================================================
// cURL helpers with error handling
// ============================================================
function glpiRequest($ep, $method, $h, $body = null) {
    global $glpiUrl;
    $url = "$glpiUrl/apirest.php/$ep";
    $ch  = curl_init($url);
    $opts = [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER     => $h,
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_CONNECTTIMEOUT => 5,
    ];
    if ($method === 'POST') {
        $opts[CURLOPT_POST] = true;
        $opts[CURLOPT_POSTFIELDS] = json_encode($body);
    } elseif ($method === 'PUT') {
        $opts[CURLOPT_CUSTOMREQUEST] = 'PUT';
        $opts[CURLOPT_POSTFIELDS] = json_encode($body);
    }
    curl_setopt_array($ch, $opts);
    $r    = curl_exec($ch);
    $err  = curl_error($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($r === false) {
        error_log("[GLPI] cURL error on $method $url: $err");
        return ['_error' => "เชื่อมต่อ GLPI server ไม่ได้: $err"];
    }
    $data = json_decode($r, true);
    if ($code >= 400) {
        $msg = $data[1] ?? $data['message'] ?? "HTTP $code";
        error_log("[GLPI] API error $method $url: HTTP $code - $msg");
        return ['_error' => $msg, '_code' => $code];
    }
    return $data;
}
function glpiGet($ep, $h)     { return glpiRequest($ep, 'GET', $h); }
function glpiPut($ep, $h, $b) { return glpiRequest($ep, 'PUT', $h, $b); }
function glpiPost($ep, $h, $b){ return glpiRequest($ep, 'POST', $h, $b); }

function createGlpiUser($lark, $headers) {
    $randomPassword = bin2hex(random_bytes(24));
    $res = glpiPost('User', $headers, ['input' => [
        'name'      => $lark,
        'password'  => $randomPassword,
        'password2' => $randomPassword,
        'realname'  => $lark,
        'is_active' => 1,
    ]]);
    if (isset($res['_error'])) {
        error_log("[GLPI] Failed to create user '$lark': " . $res['_error']);
        return null;
    }
    return $res['id'] ?? null;
}

function findExactMatch(array $response, string $name): ?array {
    $matches = array_values(array_filter($response['data'] ?? [], fn($row) => isset($row['1']) && strcasecmp(trim((string)$row['1']), $name) === 0));
    return count($matches) === 1 ? $matches[0] : null;
}

// ============================================================
// Logic
// ============================================================
$hostname = strtoupper(trim($_GET['hn'] ?? $_POST['hn'] ?? ''));
if ($hostname !== '' && !isValidHostname($hostname)) $hostname = '';
$registrationToken = trim($_GET['rt'] ?? $_POST['rt'] ?? '');
$result   = null;
$error    = null;
$success  = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Rate limit check
    $clientIpRL = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
    if (!checkRateLimit($clientIpRL)) {
        logEvent('WARN', "Rate limit exceeded");
        $error = "คุณส่งคำขอบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่";
    }

    // CSRF validation
    if (!$error) {
        $token = $_POST['csrf_token'] ?? '';
        if (!hash_equals($_SESSION['csrf_token'], $token)) {
            logEvent('WARN', "CSRF validation failed");
            $error = "Invalid request. Please reload the page and try again.";
        }
    }

    $lark        = trim($_POST['lark']         ?? '');
    $dept        = trim($_POST['dept']          ?? '');
    $subdept     = trim($_POST['subdept']       ?? '');
    $assetNumber = trim($_POST['asset_number']  ?? '');

    // Input length validation
    if (!$error && mb_strlen($lark) > 50)        $error = "Lark account ยาวเกินไป (สูงสุด 50 ตัวอักษร)";
    if (!$error && mb_strlen($assetNumber) > 30) $error = "Asset number ยาวเกินไป (สูงสุด 30 ตัวอักษร)";
    if (!$error && !preg_match('/^[a-zA-Z0-9_.\-@]+$/', $lark)) $error = "Lark account มีอักขระไม่ถูกต้อง";

    $clientIp  = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
    $appToken  = getAppToken($clientIp);
    $deptLabel = $subdept ? "$dept / $subdept" : $dept;

    if (!$error && empty($lark))         $error = "กรุณากรอก Lark account";
    elseif (!$error && empty($dept))     $error = "กรุณาเลือกแผนก";
    elseif (!$error && empty($hostname)) $error = "ไม่พบชื่อเครื่อง กรุณาใช้ shortcut ที่ IT ส่งให้";
    elseif (!$error && !array_key_exists($dept, $departments)) $error = "แผนกไม่ถูกต้อง";
    elseif (!$error && $subdept !== '' && !in_array($subdept, $departments[$dept], true)) $error = "แผนกย่อยไม่ถูกต้อง";
    elseif (!$error && !isAllowedClient($clientIp)) $error = "เครือข่ายนี้ไม่ได้รับอนุญาตให้ลงทะเบียน";
    elseif (!$error && !$appToken) $error = "ไม่พบ GLPI application token สำหรับเครือข่ายนี้";
    elseif (!$error && !verifyRegistrationToken($registrationToken, $hostname, $lark)) $error = "ลิงก์ลงทะเบียนไม่ถูกต้อง หมดอายุ หรือไม่ได้ออกให้บัญชีนี้";
    else {
        $headers = [
            "App-Token: $appToken",
            "Authorization: user_token $userToken",
            "Content-Type: application/json",
        ];
        $session = glpiGet('initSession', $headers);
        if (isset($session['_error'])) {
            logEvent('ERROR', "initSession failed", ['error' => $session['_error']]);
            $error = "เชื่อมต่อ GLPI ไม่ได้ กรุณาติดต่อ IT";
        } elseif (!isset($session['session_token'])) {
            logEvent('ERROR', "initSession: no token", ['response' => $session]);
            $error = "เชื่อมต่อ GLPI ไม่ได้ กรุณาติดต่อ IT";
        } else {
            $headers[] = "Session-Token: " . $session['session_token'];

            $enc  = urlencode($hostname);
            $cRes = glpiGet("search/Computer?criteria[0][field]=1&criteria[0][searchtype]=equals&criteria[0][value]=$enc&forcedisplay[0]=1&forcedisplay[1]=2&range=0-1", $headers);
            $cRow = findExactMatch($cRes, $hostname);

            if (!$cRow || empty($cRow['2'])) {
                $error = "ไม่พบเครื่อง '$hostname' ใน GLPI กรุณารอสัก 5 นาทีแล้วลองใหม่";
            } else {
                $cId  = $cRow['2'];

                $larkEnc     = urlencode($lark);
                $uRes        = glpiGet("search/User?criteria[0][field]=1&criteria[0][searchtype]=equals&criteria[0][value]=$larkEnc&forcedisplay[0]=1&forcedisplay[1]=2&range=0-1", $headers);
                $uRow        = findExactMatch($uRes, $lark);
                $userCreated = false;

                if (!$uRow && $cfg['allowUserCreation']) {
                    $newUserId = createGlpiUser($lark, $headers);
                    if ($newUserId) {
                        $uRes        = ['data' => [['2' => $newUserId, '1' => $lark]]];
                        $uRow        = $uRes['data'][0];
                        $userCreated = true;
                    }
                }

                $gId     = null;
                $gSearch = urlencode($subdept ?: $dept);
                $gRes    = glpiGet("search/Group?criteria[0][field]=1&criteria[0][searchtype]=equals&criteria[0][value]=$gSearch&forcedisplay[0]=1&forcedisplay[1]=2&range=0-1", $headers);
                $gRow    = findExactMatch($gRes, $subdept ?: $dept);
                if ($gRow && !empty($gRow['2'])) $gId = $gRow['2'];

                $input = [
                    'id'        => (int)$cId,
                    'states_id' => $cfg['defaultComputerStateId'],
                    'comment'   => "Dept: $deptLabel | Lark: $lark",
                ];
                if ($assetNumber !== '')   $input[$cfg['assetNumberField']] = $assetNumber;
                if ($uRow && !empty($uRow['2'])) $input['users_id'] = (int)$uRow['2'];
                if ($gId) $input['groups_id'] = (int)$gId;

                $putRes = glpiPut("Computer/$cId", $headers, ['input' => $input]);
                if (isset($putRes['_error'])) {
                    logEvent('ERROR', "Update computer failed", ['computer_id' => $cId, 'error' => $putRes['_error']]);
                    $error = "อัปเดตข้อมูลเครื่องไม่สำเร็จ กรุณาลองใหม่หรือติดต่อ IT";
                } elseif (!consumeRegistrationToken($registrationToken)) {
                    logEvent('WARN', "Registration token already used", ['hostname' => $hostname]);
                    $error = "ลิงก์ลงทะเบียนนี้ถูกใช้งานแล้ว กรุณาติดต่อ IT";
                } else {
                    $success = true;
                    logEvent('INFO', "Registration success", ['hostname' => $hostname, 'lark' => $lark, 'dept' => $deptLabel]);
                    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
                    $result  = [
                        'lark'         => $lark,
                        'dept'         => $deptLabel,
                        'computer'     => $hostname,
                        'asset_number' => $assetNumber,
                        'user_linked'  => $uRow !== null,
                        'user_created' => $userCreated,
                        'group_linked' => $gId !== null,
                    ];
                }
            }
            glpiGet('killSession', $headers);
        }
    }
}
?>
<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>ลงทะเบียนเครื่อง — IT Automation Toolkit</title>
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{--bg:#eef5f4;--surface:#ffffff;--border:#c8deda;--accent:#3aab8c;--text:#1a2e2b;--muted:#7aa098;--green:#2e9e74;--red:#d95f5f}
body{min-height:100vh;background:var(--bg);display:flex;flex-direction:column;align-items:center;justify-content:center;padding:24px;font-family:'Leelawadee UI',Tahoma,sans-serif;color:var(--text)}
.wrap{width:100%;max-width:420px}
.logo{font-family:Consolas,'Courier New',monospace;font-size:11px;color:var(--accent);letter-spacing:.14em;text-transform:uppercase;margin-bottom:28px;display:flex;align-items:center;gap:8px}
.logo::before{content:'';display:block;width:20px;height:1px;background:var(--accent)}
.card{background:var(--surface);border:1px solid var(--border);border-radius:10px;overflow:hidden;box-shadow:0 4px 28px rgba(46,158,116,.10)}
.card-top{padding:28px 28px 0}
h1{font-size:22px;font-weight:600;line-height:1.3;margin-bottom:6px;color:var(--text)}
.sub{font-size:14px;color:var(--muted);line-height:1.6;margin-bottom:24px}
.device-box{background:#f2faf8;border:1px solid var(--border);border-radius:6px;padding:12px 16px;margin-bottom:24px;display:flex;align-items:center;gap:12px}
.dot{width:8px;height:8px;border-radius:50%;background:<?= $hostname?'var(--green)':'var(--red)'?>;flex-shrink:0;animation:blink 2s infinite}
@keyframes blink{0%,100%{opacity:1}50%{opacity:.35}}
.device-label{font-family:Consolas,'Courier New',monospace;font-size:10px;color:var(--muted);letter-spacing:.08em;text-transform:uppercase;margin-bottom:3px}
.device-name{font-family:Consolas,'Courier New',monospace;font-size:14px;font-weight:600;color:var(--text)}
.card-body{padding:0 28px 28px}
.field{margin-bottom:16px}
label{display:block;font-family:Consolas,'Courier New',monospace;font-size:10px;letter-spacing:.1em;color:var(--muted);text-transform:uppercase;margin-bottom:8px}
input[type=text],select{width:100%;background:#f7fbfa;border:1px solid var(--border);border-radius:6px;padding:12px 16px;font-family:'Leelawadee UI',Tahoma,sans-serif;font-size:15px;color:var(--text);outline:none;transition:border-color .15s,box-shadow .15s;appearance:none;-webkit-appearance:none}
input[type=text]:focus,select:focus{border-color:var(--accent);box-shadow:0 0 0 3px rgba(58,171,140,.14)}
input[type=text]::placeholder{color:var(--muted);opacity:.6}
.select-wrap{position:relative}
.select-wrap::after{content:'';position:absolute;right:14px;top:50%;transform:translateY(-50%) rotate(0deg);border:5px solid transparent;border-top-color:var(--muted);margin-top:3px;pointer-events:none}
select option{background:#ffffff;color:var(--text)}
select:disabled{opacity:.4;cursor:not-allowed}
.dept-row{display:grid;grid-template-columns:1fr 1fr;gap:10px}
button{width:100%;margin-top:6px;padding:14px;background:var(--accent);color:#ffffff;border:none;border-radius:6px;font-family:'Leelawadee UI',Tahoma,sans-serif;font-size:15px;font-weight:600;cursor:pointer;transition:opacity .15s,transform .1s,box-shadow .15s;box-shadow:0 2px 12px rgba(46,158,116,.30)}
button:hover{opacity:.90;box-shadow:0 4px 18px rgba(46,158,116,.40)}
button:active{transform:scale(.98)}
.msg{margin-top:16px;padding:14px 16px;border-radius:6px;font-size:14px;line-height:1.6}
.ok{background:#eaf8f2;border:1px solid #9ed8c0;color:#1d6448}
.err{background:#fdf0f0;border:1px solid #ebbdbd;color:var(--red)}
.ok-title{font-size:16px;font-weight:600;margin-bottom:12px;color:var(--green)}
.ok-row{display:flex;justify-content:space-between;align-items:center;font-size:12px;font-family:Consolas,'Courier New',monospace;padding:6px 0;border-bottom:1px solid #c4e8d8}
.ok-row:last-child{border-bottom:none}
.ok-key{color:var(--muted)}
.ok-val{color:var(--green)}
.badge{display:inline-block;font-size:10px;padding:2px 8px;border-radius:99px;font-family:Consolas,'Courier New',monospace;font-weight:600}
.b-ok{background:#cff2e4;color:var(--green)}
.b-warn{background:#fef3d0;color:#a07010}
.card-foot{border-top:1px solid var(--border);padding:12px 28px;font-family:Consolas,'Courier New',monospace;font-size:10px;color:var(--muted);display:flex;justify-content:space-between;background:#f7fbfa}
</style>
</head>
<body>
<div class="wrap">
  <div class="logo">IT Automation Toolkit &mdash; Asset Registration</div>
  <div class="card">
    <div class="card-top">
      <h1>ลงทะเบียนเครื่องนี้</h1>
      <p class="sub">กรอกข้อมูลเพื่อผูกเครื่องกับระบบ IT</p>
      <div class="device-box">
        <div class="dot"></div>
        <div>
          <div class="device-label">Computer name</div>
          <div class="device-name"><?= htmlspecialchars($hostname ?: 'ไม่พบชื่อเครื่อง — กรุณาใช้ shortcut จาก IT', ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8') ?></div>
        </div>
      </div>
    </div>
    <div class="card-body">
    <?php if ($success): ?>
      <div class="msg ok">
        <div class="ok-title">&#10003; ลงทะเบียนสำเร็จ!</div>
        <div class="ok-row"><span class="ok-key">Computer</span><span class="ok-val"><?= htmlspecialchars($result['computer']) ?></span></div>
        <div class="ok-row"><span class="ok-key">Lark</span><span class="ok-val"><?= htmlspecialchars($result['lark']) ?></span></div>
        <div class="ok-row"><span class="ok-key">Department</span><span class="ok-val"><?= htmlspecialchars($result['dept']) ?></span></div>
        <?php if ($result['asset_number'] !== ''): ?>
        <div class="ok-row"><span class="ok-key">Asset No.</span><span class="ok-val"><?= htmlspecialchars($result['asset_number']) ?></span></div>
        <?php endif; ?>
        <div class="ok-row">
          <span class="ok-key">User</span>
          <?php if ($result['user_created']): ?>
            <span class="badge b-ok">Created + Linked</span>
          <?php elseif ($result['user_linked']): ?>
            <span class="badge b-ok">Linked</span>
          <?php else: ?>
            <span class="badge b-warn">Saved as note</span>
          <?php endif; ?>
        </div>
        <div class="ok-row">
          <span class="ok-key">Group</span>
          <span class="badge <?= $result['group_linked']?'b-ok':'b-warn' ?>"><?= $result['group_linked']?'Linked':'Not found in GLPI' ?></span>
        </div>
      </div>
    <?php else: ?>
      <form method="POST" action="?hn=<?= urlencode($hostname) ?><?= $registrationToken !== '' ? '&amp;rt=' . urlencode($registrationToken) : '' ?>">
        <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
        <?php if ($registrationToken !== ''): ?>
        <input type="hidden" name="rt" value="<?= htmlspecialchars($registrationToken, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8') ?>">
        <?php endif; ?>
        <div class="field">
          <label for="lark">Lark Account</label>
          <input type="text" id="lark" name="lark" placeholder="เช่น Dave_IT"
            value="<?= htmlspecialchars($_POST['lark'] ?? '') ?>" autocomplete="off">
        </div>
        <div class="field">
          <label for="asset_number">Inventory / Asset Number <span style="color:var(--muted);font-size:9px">(ถ้ามี)</span></label>
          <input type="text" id="asset_number" name="asset_number" placeholder="เช่น PJ-IT-0042"
            value="<?= htmlspecialchars($_POST['asset_number'] ?? '') ?>" autocomplete="off">
        </div>
        <div class="field">
          <label>แผนก / Department</label>
          <div class="dept-row">
            <div class="select-wrap">
              <select id="dept" name="dept" required onchange="updateSub(this.value)">
                <option value="">-- เลือกแผนก --</option>
                <?php foreach ($departments as $d => $s): ?>
                <option value="<?= htmlspecialchars($d) ?>" <?= ($_POST['dept']??'')===$d?'selected':'' ?>><?= htmlspecialchars($d) ?></option>
                <?php endforeach; ?>
              </select>
            </div>
            <div class="select-wrap">
              <select id="subdept" name="subdept" disabled>
                <option value="">-- แผนกย่อย --</option>
              </select>
            </div>
          </div>
        </div>
        <button type="submit">ลงทะเบียน</button>
        <?php if ($error): ?>
        <div class="msg err">&#9888;&nbsp;<?= htmlspecialchars($error) ?></div>
        <?php endif; ?>
      </form>
    <?php endif; ?>
    </div>
    <div class="card-foot">
      <span>IT Automation Toolkit</span>
      <span><?= htmlspecialchars($_SERVER['REMOTE_ADDR'] ?? '') ?></span>
    </div>
  </div>
</div>
<script>
const subsMap = <?= json_encode(array_map(fn($v)=>$v, $departments), JSON_UNESCAPED_UNICODE) ?>;
function updateSub(dept) {
  const sel  = document.getElementById('subdept');
  const list = subsMap[dept] || [];
  sel.innerHTML = '<option value="">-- แผนกย่อย --</option>';
  if (list.length === 0) { sel.disabled = true; return; }
  sel.disabled = false;
  list.forEach(s => {
    const o = document.createElement('option');
    o.value = s; o.textContent = s;
    sel.appendChild(o);
  });
}
const savedDept = <?= json_encode($_POST['dept']    ?? '') ?>;
const savedSub  = <?= json_encode($_POST['subdept'] ?? '') ?>;
if (savedDept) {
  updateSub(savedDept);
  if (savedSub) document.getElementById('subdept').value = savedSub;
}
</script>
</body>
</html>
