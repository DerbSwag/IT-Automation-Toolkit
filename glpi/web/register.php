<?php
// ============================================================
// อ่าน config จาก glpi_config.ini
// ============================================================
$iniPath = __DIR__ . '/glpi_config.ini';
if (!file_exists($iniPath)) {
    // fallback hardcode ถ้าไม่มีไฟล์
    $cfg = [
        'glpiUrl'   => 'http://YOUR_SERVER_IP',
        'userToken' => 'YOUR_USER_TOKEN',
        'tokens'    => [
            '192.168.1'   => 'YOUR_APP_TOKEN_VLAN1',
            '192.168.2'   => 'YOUR_APP_TOKEN_VLAN2',
            '192.168.100' => 'YOUR_APP_TOKEN_VLAN100',
            '192.168.101' => 'YOUR_APP_TOKEN_VLAN101',
            '127'         => 'YOUR_APP_TOKEN_LOCALHOST',
        ],
    ];
} else {
    $ini = parse_ini_file($iniPath, true);
    $cfg = [
        'glpiUrl'   => 'http://127.0.0.1',
        'userToken' => $ini['GLPI']['USER_TOKEN'],
        'tokens'    => [
            '192.168.1'   => $ini['APP_TOKENS']['VLAN1'],
            '192.168.2'   => $ini['APP_TOKENS']['VLAN2'],
            '192.168.100' => $ini['APP_TOKENS']['VLAN100'],
            '192.168.101' => $ini['APP_TOKENS']['VLAN101'],
            '127'         => $ini['APP_TOKENS']['LOCALHOST'],
        ],
    ];
}

$glpiUrl   = $cfg['glpiUrl'];
$userToken = $cfg['userToken'];

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

function getAppToken($ip) {
    global $cfg;
    foreach ($cfg['tokens'] as $prefix => $token) {
        if (strpos($ip, $prefix) === 0) return $token;
    }
    return $cfg['tokens']['192.168.1']; // default VLAN1
}

// ============================================================
// cURL helpers
// ============================================================
function glpiGet($ep, $h) {
    global $glpiUrl;
    $ch = curl_init("$glpiUrl/apirest.php/$ep");
    curl_setopt_array($ch,[
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER     => $h,
        CURLOPT_TIMEOUT        => 10,
        CURLOPT_CONNECTTIMEOUT => 5,
    ]);
    $r = curl_exec($ch);
    curl_close($ch);
    return json_decode($r, true);
}
function glpiPut($ep, $h, $b) {
    global $glpiUrl;
    $ch = curl_init("$glpiUrl/apirest.php/$ep");
    curl_setopt_array($ch,[
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CUSTOMREQUEST  => 'PUT',
        CURLOPT_HTTPHEADER     => $h,
        CURLOPT_POSTFIELDS     => json_encode($b),
        CURLOPT_TIMEOUT        => 10,
        CURLOPT_CONNECTTIMEOUT => 5,
    ]);
    $r = curl_exec($ch);
    curl_close($ch);
    return json_decode($r, true);
}
function glpiPost($ep, $h, $b) {
    global $glpiUrl;
    $ch = curl_init("$glpiUrl/apirest.php/$ep");
    curl_setopt_array($ch,[
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_HTTPHEADER     => $h,
        CURLOPT_POSTFIELDS     => json_encode($b),
        CURLOPT_TIMEOUT        => 10,
        CURLOPT_CONNECTTIMEOUT => 5,
    ]);
    $r = curl_exec($ch);
    curl_close($ch);
    return json_decode($r, true);
}

function createGlpiUser($lark, $empId, $headers) {
    $res = glpiPost('User', $headers, ['input' => [
        'name'      => $lark,
        'password'  => $empId,
        'password2' => $empId,
        'realname'  => $lark,
        'is_active' => 1,
    ]]);
    return $res['id'] ?? null;
}

// ============================================================
// Logic
// ============================================================
$hostname = strtoupper(trim($_GET['hn'] ?? $_POST['hn'] ?? ''));
$result   = null;
$error    = null;
$success  = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $lark        = trim($_POST['lark']         ?? '');
    $empId       = trim($_POST['emp_id']        ?? '');
    $dept        = trim($_POST['dept']          ?? '');
    $subdept     = trim($_POST['subdept']       ?? '');
    $assetNumber = trim($_POST['asset_number']  ?? '');

    $clientIp  = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
    $appToken  = getAppToken($clientIp);
    $curlToken = $cfg['tokens']['127']; // localhost token สำหรับ cURL
    $deptLabel = $subdept ? "$dept / $subdept" : $dept;

    if (empty($lark))         $error = "กรุณากรอก Lark account";
    elseif (empty($empId))    $error = "กรุณากรอกรหัสพนักงาน";
    elseif (empty($dept))     $error = "กรุณาเลือกแผนก";
    elseif (empty($hostname)) $error = "ไม่พบชื่อเครื่อง กรุณาใช้ shortcut ที่ IT ส่งให้";
    else {
        $headers = [
            "App-Token: $curlToken",
            "Authorization: user_token $userToken",
            "Content-Type: application/json",
        ];
        $session = glpiGet('initSession', $headers);
        if (!isset($session['session_token'])) {
            // debug info (ซ่อนจาก user, ดูได้จาก php error log)
            error_log("[GLPI Register] initSession failed. IP=$clientIp Token=$appToken URL=$glpiUrl Response=" . json_encode($session));
            $error = "เชื่อมต่อ GLPI ไม่ได้ กรุณาติดต่อ IT";
        } else {
            $headers[] = "Session-Token: " . $session['session_token'];

            $enc  = urlencode($hostname);
            $cRes = glpiGet("search/Computer?criteria[0][field]=1&criteria[0][searchtype]=contains&criteria[0][value]=$enc&forcedisplay[0]=1&forcedisplay[1]=2&range=0-5", $headers);

            if (empty($cRes['data'])) {
                $error = "ไม่พบเครื่อง '$hostname' ใน GLPI กรุณารอสัก 5 นาทีแล้วลองใหม่";
            } else {
                $cRow = $cRes['data'][0];
                $cId  = $cRow['2'] ?? $cRow['1'] ?? null;

                $larkEnc     = urlencode($lark);
                $uRes        = glpiGet("search/User?criteria[0][field]=1&criteria[0][searchtype]=contains&criteria[0][value]=$larkEnc&forcedisplay[0]=1&forcedisplay[1]=2&range=0-5", $headers);
                $userCreated = false;

                if (empty($uRes['data'])) {
                    $newUserId = createGlpiUser($lark, $empId, $headers);
                    if ($newUserId) {
                        $uRes        = ['data' => [['2' => $newUserId, '1' => $lark]]];
                        $userCreated = true;
                    }
                }

                $gId     = null;
                $gSearch = urlencode($subdept ?: $dept);
                $gRes    = glpiGet("search/Group?criteria[0][field]=1&criteria[0][searchtype]=contains&criteria[0][value]=$gSearch&forcedisplay[0]=1&forcedisplay[1]=2&range=0-5", $headers);
                if (!empty($gRes['data'])) {
                    $gRow = $gRes['data'][0];
                    $gId  = $gRow['2'] ?? $gRow['1'] ?? null;
                }

                $input = [
                    'id'        => (int)$cId,
                    'states_id' => 1,
                    'comment'   => "Dept: $deptLabel | Lark: $lark",
                ];
                if ($assetNumber !== '')   $input['otherserial'] = $assetNumber;
                if (!empty($uRes['data'])) {
                    $uRow = $uRes['data'][0];
                    $input['users_id'] = (int)($uRow['2'] ?? $uRow['1']);
                }
                if ($gId) $input['groups_id'] = (int)$gId;

                glpiPut("Computer/$cId", $headers, ['input' => $input]);

                $success = true;
                $result  = [
                    'lark'         => $lark,
                    'emp_id'       => $empId,
                    'dept'         => $deptLabel,
                    'computer'     => $hostname,
                    'asset_number' => $assetNumber,
                    'user_linked'  => !empty($uRes['data']),
                    'user_created' => $userCreated,
                    'group_linked' => !empty($gRes['data']),
                ];
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
<title>ลงทะเบียนเครื่อง — PJPARAWOOD IT</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600&family=Sarabun:wght@300;400;600&display=swap');
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{--bg:#eef5f4;--surface:#ffffff;--border:#c8deda;--accent:#3aab8c;--text:#1a2e2b;--muted:#7aa098;--green:#2e9e74;--red:#d95f5f}
body{min-height:100vh;background:var(--bg);display:flex;flex-direction:column;align-items:center;justify-content:center;padding:24px;font-family:'Sarabun',sans-serif;color:var(--text)}
.wrap{width:100%;max-width:420px}
.logo{font-family:'IBM Plex Mono',monospace;font-size:11px;color:var(--accent);letter-spacing:.14em;text-transform:uppercase;margin-bottom:28px;display:flex;align-items:center;gap:8px}
.logo::before{content:'';display:block;width:20px;height:1px;background:var(--accent)}
.card{background:var(--surface);border:1px solid var(--border);border-radius:10px;overflow:hidden;box-shadow:0 4px 28px rgba(46,158,116,.10)}
.card-top{padding:28px 28px 0}
h1{font-size:22px;font-weight:600;line-height:1.3;margin-bottom:6px;color:var(--text)}
.sub{font-size:14px;color:var(--muted);line-height:1.6;margin-bottom:24px}
.device-box{background:#f2faf8;border:1px solid var(--border);border-radius:6px;padding:12px 16px;margin-bottom:24px;display:flex;align-items:center;gap:12px}
.dot{width:8px;height:8px;border-radius:50%;background:<?= $hostname?'var(--green)':'var(--red)'?>;flex-shrink:0;animation:blink 2s infinite}
@keyframes blink{0%,100%{opacity:1}50%{opacity:.35}}
.device-label{font-family:'IBM Plex Mono',monospace;font-size:10px;color:var(--muted);letter-spacing:.08em;text-transform:uppercase;margin-bottom:3px}
.device-name{font-family:'IBM Plex Mono',monospace;font-size:14px;font-weight:600;color:var(--text)}
.card-body{padding:0 28px 28px}
.field{margin-bottom:16px}
label{display:block;font-family:'IBM Plex Mono',monospace;font-size:10px;letter-spacing:.1em;color:var(--muted);text-transform:uppercase;margin-bottom:8px}
input[type=text],select{width:100%;background:#f7fbfa;border:1px solid var(--border);border-radius:6px;padding:12px 16px;font-family:'Sarabun',sans-serif;font-size:15px;color:var(--text);outline:none;transition:border-color .15s,box-shadow .15s;appearance:none;-webkit-appearance:none}
input[type=text]:focus,select:focus{border-color:var(--accent);box-shadow:0 0 0 3px rgba(58,171,140,.14)}
input[type=text]::placeholder{color:var(--muted);opacity:.6}
.select-wrap{position:relative}
.select-wrap::after{content:'';position:absolute;right:14px;top:50%;transform:translateY(-50%) rotate(0deg);border:5px solid transparent;border-top-color:var(--muted);margin-top:3px;pointer-events:none}
select option{background:#ffffff;color:var(--text)}
select:disabled{opacity:.4;cursor:not-allowed}
.dept-row{display:grid;grid-template-columns:1fr 1fr;gap:10px}
button{width:100%;margin-top:6px;padding:14px;background:var(--accent);color:#ffffff;border:none;border-radius:6px;font-family:'Sarabun',sans-serif;font-size:15px;font-weight:600;cursor:pointer;transition:opacity .15s,transform .1s,box-shadow .15s;box-shadow:0 2px 12px rgba(46,158,116,.30)}
button:hover{opacity:.90;box-shadow:0 4px 18px rgba(46,158,116,.40)}
button:active{transform:scale(.98)}
.msg{margin-top:16px;padding:14px 16px;border-radius:6px;font-size:14px;line-height:1.6}
.ok{background:#eaf8f2;border:1px solid #9ed8c0;color:#1d6448}
.err{background:#fdf0f0;border:1px solid #ebbdbd;color:var(--red)}
.ok-title{font-size:16px;font-weight:600;margin-bottom:12px;color:var(--green)}
.ok-row{display:flex;justify-content:space-between;align-items:center;font-size:12px;font-family:'IBM Plex Mono',monospace;padding:6px 0;border-bottom:1px solid #c4e8d8}
.ok-row:last-child{border-bottom:none}
.ok-key{color:var(--muted)}
.ok-val{color:var(--green)}
.badge{display:inline-block;font-size:10px;padding:2px 8px;border-radius:99px;font-family:'IBM Plex Mono',monospace;font-weight:600}
.b-ok{background:#cff2e4;color:var(--green)}
.b-warn{background:#fef3d0;color:#a07010}
.card-foot{border-top:1px solid var(--border);padding:12px 28px;font-family:'IBM Plex Mono',monospace;font-size:10px;color:var(--muted);display:flex;justify-content:space-between;background:#f7fbfa}
</style>
</head>
<body>
<div class="wrap">
  <div class="logo">IT PJPARAWOOD &mdash; Asset Registration</div>
  <div class="card">
    <div class="card-top">
      <h1>ลงทะเบียนเครื่องนี้</h1>
      <p class="sub">กรอกข้อมูลเพื่อผูกเครื่องกับระบบ IT</p>
      <div class="device-box">
        <div class="dot"></div>
        <div>
          <div class="device-label">Computer name</div>
          <div class="device-name"><?= $hostname ?: 'ไม่พบชื่อเครื่อง — กรุณาใช้ shortcut จาก IT' ?></div>
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
      <form method="POST" action="?hn=<?= urlencode($hostname) ?>">
        <div class="field">
          <label for="lark">Lark Account</label>
          <input type="text" id="lark" name="lark" placeholder="เช่น Dave_IT"
            value="<?= htmlspecialchars($_POST['lark'] ?? '') ?>" autocomplete="off">
        </div>
        <div class="field">
          <label for="emp_id">รหัสพนักงาน <span style="color:var(--muted);font-size:9px">(ใช้เป็นรหัสผ่าน GLPI)</span></label>
          <input type="text" id="emp_id" name="emp_id" placeholder="เช่น 9124"
            value="<?= htmlspecialchars($_POST['emp_id'] ?? '') ?>" autocomplete="off" inputmode="numeric">
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
      <span>PJPARAWOOD IT</span>
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
