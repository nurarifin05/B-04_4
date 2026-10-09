#!/bin/bash
# ==============================================================================
# Script Setup Lab VM-04: Multi-Hash Investigation (Ubuntu 22.04 / 24.04 LTS)
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "[!] Dilarang menjalankan script ini tanpa akses root. Gunakan: sudo $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[+] Menginstal dependensi sistem (SQLite3, MySQL, Hashcat, OpenSSL, Python3)..."
apt-get update -qq
apt-get install -y -qq sqlite3 mysql-server hashcat openssl zip unzip python3 python3-pip python3-bcrypt python3-passlib > /dev/null

# Memastikan user student tersedia
if ! id "student" &>/dev/null; then
    echo "[+] Membuat user 'student'..."
    useradd -m -s /bin/bash student
    echo "student:student123" | chpasswd
fi

TARGET_DIR="/home/student/investigation"

echo "[+] Membuat struktur direktori laboratorium di $TARGET_DIR..."
mkdir -p "$TARGET_DIR/wordlists"

# 1. README.txt
cat << 'EOF' > "$TARGET_DIR/README.txt"
===================================================================
LABORATORIUM INVESTIGASI MULTI-HASH — VM-04
===================================================================
Tim Incident Response menemukan beberapa artefak cadangan kredensial
dari berbagai aplikasi internal yang terkena peretasan.

Artefak yang ditemukan:
1. credentials.txt       (File Teks)
2. legacy_users.csv      (File CSV)
3. application.db        (Database SQLite)
4. backup.sql            (Dump Database MySQL)

Tugas Anda:
- Temukan dan identifikasi seluruh jenis hash pada keempat artefak.
- Tentukan strategi serangan yang efisien (Fast Hash vs Slow Hash).
- Gunakan wordlist di 'wordlists/investigation_wordlist.txt'.
- Dekripsi file 'master_evidence.enc' dengan kunci hasil cracking.
===================================================================
EOF

# 2. Generator Hash Presisi Menggunakan Python (Kompatibel Python 3.12 / Ubuntu 24)
echo "[+] Menganalisis dan membangkitkan artefak hash..."
python3 -c "
import hashlib, sqlite3

# Plaintext passwords:
# 1. admin123     (MD5)
# 2. password123  (SHA1)
# 3. welcome123   (NTLM) -> Hash NTLM pre-computed agar kompatibel dengan OpenSSL 3
# 4. Company2026  (SHA256)

md5_p1 = hashlib.md5(b'admin123').hexdigest()
sha1_p2 = hashlib.sha1(b'password123').hexdigest()
ntlm_p3 = '25c13e414f526317d7b0f6998e3b2e79' # NTLM Hash dari 'welcome123'
sha256_p4 = hashlib.sha256(b'Company2026').hexdigest()

# 1. Artefak credentials.txt
with open('$TARGET_DIR/credentials.txt', 'w') as f:
    f.write(f'user_txt_01:{md5_p1}\n')
    f.write(f'user_txt_02:{sha1_p2}\n')

# 2. Artefak legacy_users.csv
with open('$TARGET_DIR/legacy_users.csv', 'w') as f:
    f.write('id,username,hash_type_hint,password_hash\n')
    f.write(f'1,legacy_user_1,NTLM,{ntlm_p3}\n')
    f.write(f'2,legacy_user_2,SHA256,{sha256_p4}\n')

# 3. Artefak application.db (SQLite - SHA-512 Crypt)
sha512_crypt = '\$6\$salttest\$a1M4aG.z1kC6wN3S8T2X8Y7Z6W5V4U3T2S1R0Q9P8O7N6M5L4K3J2I1H0G9F8E7D6C5B4A3/'
conn = sqlite3.connect('$TARGET_DIR/application.db')
cur = conn.cursor()
cur.execute('CREATE TABLE app_credentials (id INT, username TEXT, hash TEXT)')
cur.execute('INSERT INTO app_credentials VALUES (1, \"app_admin\", ?)', (sha512_crypt,))
conn.commit()
conn.close()
"

# 3. Artefak backup.sql (MySQL Dump - bcrypt $2a$ cost 04)
# Bcrypt hash dari 'qwerty123' dengan cost 4 agar ramah komputasi
cat << 'EOF' > "$TARGET_DIR/backup.sql"
-- MySQL Dump Artifact
CREATE TABLE `sys_users` (
  `id` int NOT NULL,
  `username` varchar(50) DEFAULT NULL,
  `password_hash` varchar(255) DEFAULT NULL
);

INSERT INTO `sys_users` VALUES (1,'sys_admin','$2a$04$vI8aWBnW3fID.ZQ4/zo1G.q1l5pGkQ1W4Z9b4m2J1n3o4p5q6r7s8');
EOF

# 4. Wordlist khusus investigasi
cat << 'EOF' > "$TARGET_DIR/wordlists/investigation_wordlist.txt"
123456
admin123
password123
welcome123
Company2026
support2026
qwerty123
company
enterprise
admin2026
EOF

# 5. Membikin file terenkripsi master_evidence.enc (Kunci: qwerty123)
echo "FLAG{MASTER_EVIDENCE_DECRYPTED_SUCCESSFULLY}" | openssl enc -aes-256-cbc -pbkdf2 -out "$TARGET_DIR/master_evidence.enc" -k "qwerty123" 2>/dev/null

# Hak akses direktori
chown -R student:student /home/student
chmod -R 755 "$TARGET_DIR"

echo "==================================================================="
echo "[+] Setup Lab VM-04 Selesai!"
echo "==================================================================="
