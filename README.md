# WordPress Security Scanner & Auto-Remediator

A simple Bash tool suite for security auditing and automatic remediation of WordPress sites. The scanner identifies vulnerabilities and generates a detailed report, while the remediator parses the report and applies critical security fixes directly to your server.

---

## 🛠️ What the Scripts Do

### 1. `scanner.sh` (Security Audit)
- **Core Integrity Check**: Compares core WordPress files against official hashes from `wordpress.org`.
- **Malware & Webshell Scan**: Searches for suspicious code patterns and backdoors inside `wp-content/`.
- **Unsafe Uploads Inspection**: Detects executable `.php` scripts uploaded inside `wp-content/uploads/`.
- **File Permissions Audit**: Flags dangerous `777` directory permissions and insecure `wp-config.php` permissions.
- **Hardening & Database Checks**: Audits security directives in `wp-config.php` and scans for database script injections via WP-CLI.
- **Security Score & Report**: Generates a timestamped report file (`relatorio_seguranca_*.txt`) with a 0–100 score.

### 2. `remediador.sh` (Auto-Fix)
- **Fixes Permissions**: Changes `777` directories to `755` and hardens `wp-config.php` to `640`.
- **Blocks Dashboard Code Editor**: Injects `DISALLOW_FILE_EDIT` into `wp-config.php`.
- **Isolates PHP in Uploads**: Quarantines `.php` files inside uploads and creates an `.htaccess` rule blocking script execution.
- **Restores Native WP Core**: Overwrites modified/corrupted core files with clean official code (requires WP-CLI).
- **Cleanup**: Removes junk dot-files (such as `.DS_Store`).

---

## 🚀 Installation & Execution

### 1. Clone the repository
Navigate to your WordPress root directory (where `wp-config.php` is located) and clone the repository:

```bash
cd /path/to/your/wordpress
git clone git@github.com:EduToledoSoma/scanner-seguranca.git .
```

### 2. Grant execution permissions
Make both shell scripts executable:

```bash
chmod +x scanner.sh remediador.sh
```

### 3. Run the Security Scanner
Run the audit script to analyze your WordPress site:

```bash
./scanner.sh
```

### 4. Run the Auto-Remediator
Apply automatic fixes based on the generated scan report:

```bash
./remediador.sh
```

> **Tip:** After running the remediator, re-run `./scanner.sh` to confirm your site score reaches **100/100**.