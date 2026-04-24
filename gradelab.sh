#!/bin/bash
#
# ╔══════════════════════════════════════════════════════════════╗
# ║   RHCSA Month 1 Practice Lab — Auto-Grading Script         ║
# ║   Total: 100 points  |  Passing: 70/100                    ║
# ║   Run as root after reboot to verify persistence            ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:  chmod +x grade_lab.sh && ./grade_lab.sh
#

# ── Colors & Formatting ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

TOTAL=0
EARNED=0
TASK_NUM=0
TASK_EARNED=0
TASK_POSSIBLE=0

pass_check() {
    local points=$1
    local desc="$2"
    EARNED=$((EARNED + points))
    TASK_EARNED=$((TASK_EARNED + points))
    printf "    ${GREEN}✔  %-55s [+%d]${NC}\n" "$desc" "$points"
}

fail_check() {
    local points=$1
    local desc="$2"
    printf "    ${RED}✘  %-55s [ 0]${NC}\n" "$desc"
}

start_task() {
    local name="$1"
    local points=$2
    TASK_NUM=$((TASK_NUM + 1))
    TASK_EARNED=0
    TASK_POSSIBLE=$points
    TOTAL=$((TOTAL + points))
    echo ""
    printf "${BOLD}${CYAN}━━━ Task %d: %s ${DIM}[%d pts]${NC}\n" "$TASK_NUM" "$name" "$points"
}

end_task() {
    if [ "$TASK_EARNED" -eq "$TASK_POSSIBLE" ]; then
        printf "    ${GREEN}${BOLD}▸ Score: %d/%d — PERFECT${NC}\n" "$TASK_EARNED" "$TASK_POSSIBLE"
    elif [ "$TASK_EARNED" -gt 0 ]; then
        printf "    ${YELLOW}${BOLD}▸ Score: %d/%d — PARTIAL${NC}\n" "$TASK_EARNED" "$TASK_POSSIBLE"
    else
        printf "    ${RED}${BOLD}▸ Score: 0/%d — MISSED${NC}\n" "$TASK_POSSIBLE"
    fi
}

separator() {
    printf "${DIM}────────────────────────────────────────────────────────────────────${NC}\n"
}

# ── Pre-flight ──
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}${BOLD}ERROR: This script must be run as root.${NC}"
    echo "Usage: sudo ./grade_lab.sh"
    exit 1
fi

clear
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       RHCSA Month 1 Practice Lab — Grading Results         ║${NC}"
echo -e "${BOLD}║       $(date '+%Y-%m-%d %H:%M:%S')                                  ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"

# ════════════════════════════════════════════════════════════════
# TASK 1 — Hostname (4 pts)
# ════════════════════════════════════════════════════════════════
start_task "Set the System Hostname" 4

CURRENT_HOSTNAME=$(hostnamectl --static 2>/dev/null)
if [ "$CURRENT_HOSTNAME" = "lab.example.com" ]; then
    pass_check 2 "Static hostname is lab.example.com"
else
    fail_check 2 "Static hostname is lab.example.com (found: $CURRENT_HOSTNAME)"
fi

RUNTIME_HOSTNAME=$(hostname 2>/dev/null)
if [ "$RUNTIME_HOSTNAME" = "lab.example.com" ]; then
    pass_check 2 "Runtime hostname matches (persistent after reboot)"
else
    fail_check 2 "Runtime hostname matches (found: $RUNTIME_HOSTNAME)"
fi

end_task

# ════════════════════════════════════════════════════════════════
# TASK 2 — Users & Groups (10 pts)
# ════════════════════════════════════════════════════════════════
start_task "Create Users and Groups" 10

# Group devteam
if getent group devteam &>/dev/null; then
    pass_check 1 "Group 'devteam' exists"
else
    fail_check 1 "Group 'devteam' exists"
fi

# alice with UID 2501
if id alice &>/dev/null; then
    ALICE_UID=$(id -u alice)
    if [ "$ALICE_UID" -eq 2501 ]; then
        pass_check 1 "User 'alice' exists with UID 2501"
    else
        fail_check 1 "User 'alice' UID is 2501 (found: $ALICE_UID)"
    fi
    if id -nG alice 2>/dev/null | grep -qw devteam; then
        pass_check 1 "alice is a member of devteam"
    else
        fail_check 1 "alice is a member of devteam"
    fi
else
    fail_check 1 "User 'alice' exists with UID 2501"
    fail_check 1 "alice is a member of devteam"
fi

# bob with UID 2502
if id bob &>/dev/null; then
    BOB_UID=$(id -u bob)
    if [ "$BOB_UID" -eq 2502 ]; then
        pass_check 1 "User 'bob' exists with UID 2502"
    else
        fail_check 1 "User 'bob' UID is 2502 (found: $BOB_UID)"
    fi
    if id -nG bob 2>/dev/null | grep -qw devteam; then
        pass_check 1 "bob is a member of devteam"
    else
        fail_check 1 "bob is a member of devteam"
    fi
else
    fail_check 1 "User 'bob' exists with UID 2502"
    fail_check 1 "bob is a member of devteam"
fi

# charlie with nologin
if id charlie &>/dev/null; then
    CHARLIE_SHELL=$(getent passwd charlie | cut -d: -f7)
    if echo "$CHARLIE_SHELL" | grep -q "nologin\|/bin/false"; then
        pass_check 2 "User 'charlie' has non-interactive shell ($CHARLIE_SHELL)"
    else
        fail_check 2 "charlie has non-interactive shell (found: $CHARLIE_SHELL)"
    fi
    if id -nG charlie 2>/dev/null | grep -qw devteam; then
        fail_check 1 "charlie is NOT a member of devteam (but is!)"
    else
        pass_check 1 "charlie is NOT a member of devteam"
    fi
else
    fail_check 2 "User 'charlie' exists"
    fail_check 1 "charlie is NOT a member of devteam"
fi

# Password check (all 3 users)
PASS_OK=true
for U in alice bob charlie; do
    if ! id "$U" &>/dev/null; then
        PASS_OK=false
        continue
    fi
    # Check password is set (has a hash, not locked/empty)
    SHADOW_ENTRY=$(getent shadow "$U" 2>/dev/null | cut -d: -f2)
    if [ -z "$SHADOW_ENTRY" ] || [ "$SHADOW_ENTRY" = "!" ] || [ "$SHADOW_ENTRY" = "!!" ] || [ "$SHADOW_ENTRY" = "*" ]; then
        PASS_OK=false
    fi
done
if $PASS_OK; then
    pass_check 1 "Passwords set for alice, bob, charlie"
else
    fail_check 1 "Passwords set for alice, bob, charlie"
fi

end_task

# ════════════════════════════════════════════════════════════════
# TASK 3 — Password Aging (6 pts)
# ════════════════════════════════════════════════════════════════
start_task "Password Aging Policy" 6

if id alice &>/dev/null; then
    CHAGE_OUT=$(chage -l alice 2>/dev/null)

    MAX_DAYS=$(grep "^PASS_MAX_DAYS" /etc/shadow 2>/dev/null; getent shadow alice | cut -d: -f5)
    ALICE_MAX=$(getent shadow alice 2>/dev/null | cut -d: -f5)
    if [ "$ALICE_MAX" = "45" ]; then
        pass_check 2 "Password expires every 45 days"
    else
        fail_check 2 "Password expires every 45 days (found: $ALICE_MAX)"
    fi

    ALICE_MIN=$(getent shadow alice 2>/dev/null | cut -d: -f4)
    if [ "$ALICE_MIN" = "7" ]; then
        pass_check 2 "Minimum password age is 7 days"
    else
        fail_check 2 "Minimum password age is 7 days (found: $ALICE_MIN)"
    fi

    ALICE_WARN=$(getent shadow alice 2>/dev/null | cut -d: -f6)
    if [ "$ALICE_WARN" = "10" ]; then
        pass_check 2 "Password warning period is 10 days"
    else
        fail_check 2 "Password warning period is 10 days (found: $ALICE_WARN)"
    fi
else
    fail_check 2 "Password expires every 45 days (user alice missing)"
    fail_check 2 "Minimum password age is 7 days"
    fail_check 2 "Password warning period is 10 days"
fi

end_task

# ════════════════════════════════════════════════════════════════
# TASK 4 — Sudo (5 pts)
# ════════════════════════════════════════════════════════════════
start_task "Configure Sudo Access" 5

SUDO_FILE_FOUND=false
SUDO_CORRECT=false

# Check for drop-in file in /etc/sudoers.d/
for f in /etc/sudoers.d/*; do
    [ -f "$f" ] || continue
    if grep -qE '^%devteam' "$f" 2>/dev/null; then
        SUDO_FILE_FOUND=true
        if grep -qE '^%devteam\s+ALL=\(ALL\)\s+NOPASSWD:\s*ALL' "$f" 2>/dev/null || \
           grep -qE '^%devteam\s+ALL=\(ALL:ALL\)\s+NOPASSWD:\s*ALL' "$f" 2>/dev/null; then
            SUDO_CORRECT=true
        fi
        break
    fi
done

if $SUDO_FILE_FOUND; then
    pass_check 2 "Sudoers drop-in file exists for devteam"
else
    fail_check 2 "Sudoers drop-in file exists for devteam"
fi

if $SUDO_CORRECT; then
    pass_check 3 "devteam has NOPASSWD sudo for ALL commands"
else
    fail_check 3 "devteam has NOPASSWD sudo for ALL commands"
fi

end_task

# ════════════════════════════════════════════════════════════════
# TASK 5 — Directory Structure (6 pts)
# ════════════════════════════════════════════════════════════════
start_task "Build a Directory Structure" 6

DIRS_OK=true
for d in /projects /projects/webapp /projects/webapp/src /projects/webapp/docs /projects/database /projects/scripts; do
    if [ ! -d "$d" ]; then
        DIRS_OK=false
        break
    fi
done

if $DIRS_OK; then
    pass_check 2 "Directory tree /projects/... fully created"
else
    fail_check 2 "Directory tree /projects/... fully created"
fi

README="/projects/webapp/docs/README.md"
if [ -f "$README" ]; then
    CONTENT=$(cat "$README" 2>/dev/null)
    if [ "$CONTENT" = "Project documentation goes here" ]; then
        pass_check 2 "README.md exists with correct content"
    else
        fail_check 2 "README.md has correct content"
    fi
else
    fail_check 2 "README.md exists"
fi

if [ -f "/projects/database/.gitkeep" ]; then
    pass_check 2 "Hidden file .gitkeep exists in /projects/database/"
else
    fail_check 2 "Hidden file .gitkeep exists in /projects/database/"
fi

end_task

# ════════════════════════════════════════════════════════════════
# TASK 6 — Special Permissions (8 pts)
# ════════════════════════════════════════════════════════════════
start_task "Collaborative Directory with Special Permissions" 8

WEBAPP="/projects/webapp"
if [ -d "$WEBAPP" ]; then
    GRP_OWNER=$(stat -c '%G' "$WEBAPP" 2>/dev/null)
    if [ "$GRP_OWNER" = "devteam" ]; then
        pass_check 2 "/projects/webapp/ group ownership is devteam"
    else
        fail_check 2 "/projects/webapp/ group ownership is devteam (found: $GRP_OWNER)"
    fi

    PERMS=$(stat -c '%a' "$WEBAPP" 2>/dev/null)
    # Must be 2770 (rwxrws--- with SGID)
    if [ "$PERMS" = "2770" ]; then
        pass_check 3 "Permissions 2770 (rwx for owner/group, SGID set, no other)"
    else
        # Check individual components
        PERM_FULL=$(stat -c '%A' "$WEBAPP" 2>/dev/null)
        # Accept if SGID is set and other has no perms
        if echo "$PERMS" | grep -qE '^2[7][7][0]$'; then
            pass_check 3 "Permissions correct with SGID"
        else
            fail_check 3 "Permissions should be 2770 (found: $PERMS / $PERM_FULL)"
        fi
    fi
else
    fail_check 2 "/projects/webapp/ exists"
    fail_check 3 "Permissions 2770"
fi

SCRIPTS="/projects/scripts"
if [ -d "$SCRIPTS" ]; then
    SCRIPTS_GRP=$(stat -c '%G' "$SCRIPTS" 2>/dev/null)
    SCRIPTS_PERMS=$(stat -c '%a' "$SCRIPTS" 2>/dev/null)
    if [ "$SCRIPTS_GRP" = "devteam" ]; then
        pass_check 1 "/projects/scripts/ group ownership is devteam"
    else
        fail_check 1 "/projects/scripts/ group ownership is devteam (found: $SCRIPTS_GRP)"
    fi
    # Must be 1775 (sticky bit + rwxrwxr-x)
    if [ "$SCRIPTS_PERMS" = "1775" ]; then
        pass_check 2 "/projects/scripts/ has sticky bit set (1775)"
    else
        fail_check 2 "/projects/scripts/ sticky bit 1775 (found: $SCRIPTS_PERMS)"
    fi
else
    fail_check 1 "/projects/scripts/ exists"
    fail_check 2 "/projects/scripts/ has sticky bit"
fi

end_task

# ════════════════════════════════════════════════════════════════
# TASK 7 — File Permissions Numeric (6 pts)
# ════════════════════════════════════════════════════════════════
start_task "File Permissions with Numeric Notation" 6

HOSTSBAK="/tmp/hosts.bak"
if [ -f "$HOSTSBAK" ]; then
    pass_check 1 "/tmp/hosts.bak exists"

    FILE_OWNER=$(stat -c '%U' "$HOSTSBAK" 2>/dev/null)
    FILE_GRP=$(stat -c '%G' "$HOSTSBAK" 2>/dev/null)
    if [ "$FILE_OWNER" = "alice" ] && [ "$FILE_GRP" = "devteam" ]; then
        pass_check 2 "Owned by alice:devteam"
    else
        fail_check 2 "Owned by alice:devteam (found: $FILE_OWNER:$FILE_GRP)"
    fi

    FILE_PERMS=$(stat -c '%a' "$HOSTSBAK" 2>/dev/null)
    if [ "$FILE_PERMS" = "640" ]; then
        pass_check 3 "Permissions are 640 (-rw-r-----)"
    else
        fail_check 3 "Permissions are 640 (found: $FILE_PERMS)"
    fi
else
    fail_check 1 "/tmp/hosts.bak exists"
    fail_check 2 "Owned by alice:devteam"
    fail_check 3 "Permissions are 640"
fi

end_task

# ════════════════════════════════════════════════════════════════
# TASK 8 — Umask (6 pts)
# ════════════════════════════════════════════════════════════════
start_task "Configure Default Permissions (umask)" 6

# Required umask for -rw-r----- (files) and drwxr-x--- (dirs) is 0027
UMASK_SET=false
if id bob &>/dev/null; then
    for rc in /home/bob/.bashrc /home/bob/.bash_profile /home/bob/.profile; do
        if [ -f "$rc" ] && grep -qE '^\s*umask\s+0*27\b' "$rc" 2>/dev/null; then
            UMASK_SET=true
            break
        fi
    done

    if $UMASK_SET; then
        pass_check 3 "umask 027 configured in bob's shell profile"
    else
        fail_check 3 "umask 027 in bob's shell profile"
    fi

    # Test actual umask by simulating
    if $UMASK_SET; then
        # Create test file as bob
        TEST_DIR=$(mktemp -d)
        su - bob -c "umask; touch $TEST_DIR/testfile; mkdir $TEST_DIR/testdir" &>/dev/null
        if [ -f "$TEST_DIR/testfile" ]; then
            TEST_PERMS=$(stat -c '%a' "$TEST_DIR/testfile" 2>/dev/null)
            DIR_PERMS=$(stat -c '%a' "$TEST_DIR/testdir" 2>/dev/null)
            if [ "$TEST_PERMS" = "640" ] && [ "$DIR_PERMS" = "750" ]; then
                pass_check 3 "Verified: new files=640, new dirs=750"
            else
                fail_check 3 "Actual defaults: file=$TEST_PERMS dir=$DIR_PERMS (expected 640/750)"
            fi
        else
            fail_check 3 "Could not verify actual umask behavior"
        fi
        rm -rf "$TEST_DIR" 2>/dev/null
    else
        fail_check 3 "Actual umask behavior (skipped — not configured)"
    fi
else
    fail_check 3 "umask configuration (user bob missing)"
    fail_check 3 "Actual umask behavior"
fi

end_task

# ════════════════════════════════════════════════════════════════
# TASK 9 — Vim Config File (5 pts)
# ════════════════════════════════════════════════════════════════
start_task "Create and Edit a Configuration File with Vim" 5

APPCONF="/projects/webapp/src/app.conf"
if [ -f "$APPCONF" ]; then
    pass_check 1 "File app.conf exists"

    # Check key content lines
    EXPECTED_LINES=(
        "[general]"
        "app_name = webapp"
        "version = 1.0"
        "debug = false"
        "[network]"
        "listen_address = 0.0.0.0"
        "port = 8443"
        "[logging]"
        "log_level = info"
        "log_file = /var/log/webapp.log"
    )

    LINES_OK=true
    for line in "${EXPECTED_LINES[@]}"; do
        if ! grep -qF "$line" "$APPCONF" 2>/dev/null; then
            LINES_OK=false
            break
        fi
    done

    if $LINES_OK; then
        pass_check 4 "File content matches expected configuration"
    else
        fail_check 4 "File content matches expected configuration"
    fi
else
    fail_check 1 "File app.conf exists"
    fail_check 4 "File content"
fi

end_task

# ════════════════════════════════════════════════════════════════
# TASK 10 — I/O Redirection (8 pts)
# ════════════════════════════════════════════════════════════════
start_task "I/O Redirection" 8

# etc-listing.txt
if [ -f "/root/etc-listing.txt" ]; then
    if grep -q "hostname" /root/etc-listing.txt 2>/dev/null && grep -q "passwd" /root/etc-listing.txt 2>/dev/null; then
        pass_check 1 "/root/etc-listing.txt contains /etc/ listing"
    else
        fail_check 1 "/root/etc-listing.txt has /etc/ listing content"
    fi
    # Check date appended
    if grep -qE '[0-9]{4}|Mon|Tue|Wed|Thu|Fri|Sat|Sun|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec' /root/etc-listing.txt 2>/dev/null; then
        pass_check 1 "Date appears appended to etc-listing.txt"
    else
        fail_check 1 "Date appended to etc-listing.txt"
    fi
else
    fail_check 1 "/root/etc-listing.txt exists"
    fail_check 1 "Date appended"
fi

# stdout.txt and stderr.txt
if [ -f "/root/stdout.txt" ]; then
    if grep -q "hostname" /root/stdout.txt 2>/dev/null; then
        pass_check 2 "/root/stdout.txt has stdout (valid path output)"
    else
        fail_check 2 "/root/stdout.txt has stdout content"
    fi
else
    fail_check 2 "/root/stdout.txt exists"
fi

if [ -f "/root/stderr.txt" ]; then
    if grep -qi "no such file\|cannot access\|nonexistent" /root/stderr.txt 2>/dev/null; then
        pass_check 2 "/root/stderr.txt has stderr (error message)"
    else
        fail_check 2 "/root/stderr.txt has stderr content"
    fi
else
    fail_check 2 "/root/stderr.txt exists"
fi

# combined.txt
if [ -f "/root/combined.txt" ]; then
    HAS_STDOUT=$(grep -c "hosts" /root/combined.txt 2>/dev/null)
    HAS_STDERR=$(grep -ciE "no such file|cannot access|doesnotexist" /root/combined.txt 2>/dev/null)
    if [ "$HAS_STDOUT" -gt 0 ] && [ "$HAS_STDERR" -gt 0 ]; then
        pass_check 2 "/root/combined.txt has both stdout and stderr"
    else
        fail_check 2 "/root/combined.txt should have both stdout and stderr"
    fi
else
    fail_check 2 "/root/combined.txt exists"
fi

end_task

# ════════════════════════════════════════════════════════════════
# TASK 11 — Grep & Regex (10 pts)
# ════════════════════════════════════════════════════════════════
start_task "Grep and Regular Expressions" 10

# 11a: nologin-users.txt
if [ -f "/root/nologin-users.txt" ]; then
    NL_COUNT=$(wc -l < /root/nologin-users.txt 2>/dev/null)
    EXPECTED_NL=$(grep -c "nologin" /etc/passwd 2>/dev/null)
    if [ "$NL_COUNT" -gt 0 ] && [ "$NL_COUNT" -eq "$EXPECTED_NL" ]; then
        pass_check 2 "nologin-users.txt: correct ($NL_COUNT lines)"
    elif [ "$NL_COUNT" -gt 0 ]; then
        pass_check 1 "nologin-users.txt: partially correct ($NL_COUNT lines, expected $EXPECTED_NL)"
    else
        fail_check 2 "nologin-users.txt has content"
    fi
else
    fail_check 2 "nologin-users.txt exists"
fi

# 11b: ab-users.txt
if [ -f "/root/ab-users.txt" ]; then
    EXPECTED_AB=$(grep -c '^[ab]' /etc/passwd 2>/dev/null)
    ACTUAL_AB=$(wc -l < /root/ab-users.txt 2>/dev/null)
    if [ "$ACTUAL_AB" -eq "$EXPECTED_AB" ] && [ "$ACTUAL_AB" -gt 0 ]; then
        pass_check 2 "ab-users.txt: correct ($ACTUAL_AB lines)"
    elif [ "$ACTUAL_AB" -gt 0 ]; then
        pass_check 1 "ab-users.txt: has content but count mismatch ($ACTUAL_AB vs $EXPECTED_AB)"
    else
        fail_check 2 "ab-users.txt has content"
    fi
else
    fail_check 2 "ab-users.txt exists"
fi

# 11c: config-numbers.txt
if [ -f "/root/config-numbers.txt" ]; then
    if [ -f "$APPCONF" ]; then
        EXPECTED_NUMS=$(grep -c '[0-9]' "$APPCONF" 2>/dev/null)
        ACTUAL_NUMS=$(wc -l < /root/config-numbers.txt 2>/dev/null)
        if [ "$ACTUAL_NUMS" -eq "$EXPECTED_NUMS" ] && [ "$ACTUAL_NUMS" -gt 0 ]; then
            pass_check 2 "config-numbers.txt: correct ($ACTUAL_NUMS lines)"
        elif [ "$ACTUAL_NUMS" -gt 0 ]; then
            pass_check 1 "config-numbers.txt: partially correct"
        else
            fail_check 2 "config-numbers.txt has content"
        fi
    else
        fail_check 2 "config-numbers.txt (can't verify — app.conf missing)"
    fi
else
    fail_check 2 "config-numbers.txt exists"
fi

# 11d: blank-lines.txt and blank-count.txt
if [ -f "/root/blank-lines.txt" ]; then
    pass_check 1 "blank-lines.txt exists"
else
    fail_check 1 "blank-lines.txt exists"
fi

if [ -f "/root/blank-count.txt" ]; then
    EXPECTED_BLANKS=$(grep -c '^$' /etc/login.defs 2>/dev/null)
    ACTUAL_COUNT=$(tr -d '[:space:]' < /root/blank-count.txt 2>/dev/null)
    if [ "$ACTUAL_COUNT" = "$EXPECTED_BLANKS" ]; then
        pass_check 1 "blank-count.txt: correct count ($ACTUAL_COUNT)"
    else
        fail_check 1 "blank-count.txt: expected $EXPECTED_BLANKS (found: $ACTUAL_COUNT)"
    fi
else
    fail_check 1 "blank-count.txt exists"
fi

# 11e: shell-filter.txt (extended regex)
if [ -f "/root/shell-filter.txt" ]; then
    EXPECTED_SF=$(grep -Ec '(/bin/bash|/sbin/nologin)$' /etc/passwd 2>/dev/null)
    ACTUAL_SF=$(wc -l < /root/shell-filter.txt 2>/dev/null)
    if [ "$ACTUAL_SF" -eq "$EXPECTED_SF" ] && [ "$ACTUAL_SF" -gt 0 ]; then
        pass_check 2 "shell-filter.txt: correct ($ACTUAL_SF lines)"
    elif [ "$ACTUAL_SF" -gt 0 ]; then
        pass_check 1 "shell-filter.txt: has content ($ACTUAL_SF vs expected $EXPECTED_SF)"
    else
        fail_check 2 "shell-filter.txt has content"
    fi
else
    fail_check 2 "shell-filter.txt exists"
fi

end_task

# ════════════════════════════════════════════════════════════════
# TASK 12 — Links (8 pts)
# ════════════════════════════════════════════════════════════════
start_task "Hard Links and Symbolic Links" 8

DEPLOY="/projects/scripts/deploy.sh"

if [ -f "$DEPLOY" ]; then
    pass_check 1 "deploy.sh exists"

    if grep -q "Deploying application" "$DEPLOY" 2>/dev/null; then
        pass_check 1 "deploy.sh has correct content"
    else
        fail_check 1 "deploy.sh has correct content"
    fi

    if [ -x "$DEPLOY" ]; then
        pass_check 1 "deploy.sh is executable"
    else
        fail_check 1 "deploy.sh is executable for owner"
    fi
else
    fail_check 1 "deploy.sh exists"
    fail_check 1 "deploy.sh content"
    fail_check 1 "deploy.sh executable"
fi

# Symlink
SYMLINK="/home/alice/deploy-link"
if [ -L "$SYMLINK" ]; then
    TARGET=$(readlink -f "$SYMLINK" 2>/dev/null)
    if [ "$TARGET" = "$DEPLOY" ] || [ "$TARGET" = "$(readlink -f $DEPLOY 2>/dev/null)" ]; then
        pass_check 2 "Symbolic link /home/alice/deploy-link → deploy.sh"
    else
        fail_check 2 "Symbolic link target incorrect (points to: $TARGET)"
    fi
else
    fail_check 2 "Symbolic link /home/alice/deploy-link"
fi

# Hard link
HARDLINK="/home/bob/deploy-hard"
if [ -f "$HARDLINK" ] && [ ! -L "$HARDLINK" ]; then
    ORIG_INODE=$(stat -c '%i' "$DEPLOY" 2>/dev/null)
    HARD_INODE=$(stat -c '%i' "$HARDLINK" 2>/dev/null)
    if [ "$ORIG_INODE" = "$HARD_INODE" ]; then
        pass_check 3 "Hard link shares inode with original ($ORIG_INODE)"
    else
        fail_check 3 "Hard link inode mismatch ($HARD_INODE vs $ORIG_INODE)"
    fi
else
    if [ -L "$HARDLINK" ]; then
        fail_check 3 "deploy-hard is a symlink, not a hard link"
    else
        fail_check 3 "Hard link /home/bob/deploy-hard"
    fi
fi

end_task

# ════════════════════════════════════════════════════════════════
# TASK 13 — Archiving (8 pts)
# ════════════════════════════════════════════════════════════════
start_task "Archiving and Compression" 8

# Uncompressed tar
if [ -f "/root/projects.tar" ]; then
    if file /root/projects.tar 2>/dev/null | grep -qi "tar archive\|POSIX tar"; then
        pass_check 1 "/root/projects.tar is a valid tar archive"
    else
        fail_check 1 "/root/projects.tar is not a valid tar archive"
    fi
else
    fail_check 1 "/root/projects.tar exists"
fi

# gzip tar
if [ -f "/root/webapp.tar.gz" ]; then
    if file /root/webapp.tar.gz 2>/dev/null | grep -qi "gzip"; then
        pass_check 2 "/root/webapp.tar.gz is gzip-compressed"
    else
        fail_check 2 "/root/webapp.tar.gz is not gzip-compressed"
    fi
else
    fail_check 2 "/root/webapp.tar.gz exists"
fi

# bzip2 tar
if [ -f "/root/scripts.tar.bz2" ]; then
    if file /root/scripts.tar.bz2 2>/dev/null | grep -qi "bzip2"; then
        pass_check 2 "/root/scripts.tar.bz2 is bzip2-compressed"
    else
        fail_check 2 "/root/scripts.tar.bz2 is not bzip2-compressed"
    fi
else
    fail_check 2 "/root/scripts.tar.bz2 exists"
fi

# Extract to /tmp/restore/
if [ -d "/tmp/restore" ]; then
    if find /tmp/restore -type f 2>/dev/null | head -1 | grep -q .; then
        pass_check 1 "/tmp/restore/ has extracted content"
    else
        fail_check 1 "/tmp/restore/ is empty"
    fi
else
    fail_check 1 "/tmp/restore/ exists"
fi

# archive-contents.txt
if [ -f "/root/archive-contents.txt" ]; then
    if grep -q "deploy\|scripts" /root/archive-contents.txt 2>/dev/null; then
        pass_check 2 "archive-contents.txt has listing of scripts.tar.bz2"
    else
        fail_check 2 "archive-contents.txt has correct listing"
    fi
else
    fail_check 2 "/root/archive-contents.txt exists"
fi

end_task

# ════════════════════════════════════════════════════════════════
# TASK 14 — SSH (8 pts)
# ════════════════════════════════════════════════════════════════
start_task "SSH Key-Based Authentication" 8

if id alice &>/dev/null; then
    # Check key pair exists
    if [ -f "/home/alice/.ssh/id_rsa" ] && [ -f "/home/alice/.ssh/id_rsa.pub" ]; then
        pass_check 2 "RSA key pair exists for alice"
    elif ls /home/alice/.ssh/id_* &>/dev/null; then
        pass_check 2 "SSH key pair exists for alice"
    else
        fail_check 2 "SSH key pair for alice"
    fi

    # Check authorized_keys
    if [ -f "/home/alice/.ssh/authorized_keys" ]; then
        PUB_KEY=""
        for pk in /home/alice/.ssh/id_*.pub; do
            [ -f "$pk" ] && PUB_KEY=$(cat "$pk" 2>/dev/null) && break
        done
        if [ -n "$PUB_KEY" ] && grep -qF "$(echo "$PUB_KEY" | awk '{print $2}')" /home/alice/.ssh/authorized_keys 2>/dev/null; then
            pass_check 3 "Public key in authorized_keys (key-based auth configured)"
        else
            fail_check 3 "Public key not found in authorized_keys"
        fi
    else
        fail_check 3 "authorized_keys file missing"
    fi

    # Test actual SSH (non-interactive)
    SSH_TEST=$(su - alice -c 'ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 alice@localhost whoami' 2>/dev/null)
    if [ "$SSH_TEST" = "alice" ]; then
        pass_check 2 "SSH to localhost works without password"
    else
        fail_check 2 "SSH to localhost without password (got: '$SSH_TEST')"
    fi
else
    fail_check 2 "SSH key pair (user alice missing)"
    fail_check 3 "Key-based auth"
    fail_check 2 "SSH test"
fi

# scp test
if [ -f "/tmp/motd-copy" ]; then
    pass_check 1 "/tmp/motd-copy exists (scp completed)"
else
    fail_check 1 "/tmp/motd-copy exists"
fi

end_task

# ════════════════════════════════════════════════════════════════
# TASK 15 — Man Pages (6 pts)
# ════════════════════════════════════════════════════════════════
start_task "Man Pages Challenge" 6

# Answer 1: -p (preserve)
if [ -f "/root/man-answer1.txt" ]; then
    ANS1=$(tr -d '[:space:]' < /root/man-answer1.txt 2>/dev/null)
    if [ "$ANS1" = "-p" ]; then
        pass_check 2 "cp preserve option: correct (-p)"
    elif [ "$ANS1" = "-a" ] || [ "$ANS1" = "--preserve" ]; then
        pass_check 1 "cp preserve option: acceptable but not the single-letter asked"
    else
        fail_check 2 "cp preserve option (found: $ANS1, expected: -p)"
    fi
else
    fail_check 2 "/root/man-answer1.txt exists"
fi

# Answer 2: -v (verbose)
if [ -f "/root/man-answer2.txt" ]; then
    ANS2=$(tr -d '[:space:]' < /root/man-answer2.txt 2>/dev/null)
    if [ "$ANS2" = "-v" ] || [ "$ANS2" = "v" ]; then
        pass_check 2 "tar verbose option: correct (-v)"
    else
        fail_check 2 "tar verbose option (found: $ANS2, expected: -v)"
    fi
else
    fail_check 2 "/root/man-answer2.txt exists"
fi

# Answer 3: section 5
if [ -f "/root/man-answer3.txt" ]; then
    ANS3=$(tr -d '[:space:]' < /root/man-answer3.txt 2>/dev/null)
    if [ "$ANS3" = "5" ]; then
        pass_check 2 "Man page section for config files: correct (5)"
    else
        fail_check 2 "Man page section (found: $ANS3, expected: 5)"
    fi
else
    fail_check 2 "/root/man-answer3.txt exists"
fi

end_task

# ════════════════════════════════════════════════════════════════
# FINAL RESULTS
# ════════════════════════════════════════════════════════════════
echo ""
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"

PERCENT=$((EARNED * 100 / TOTAL))

if [ "$EARNED" -ge 70 ]; then
    STATUS="${GREEN}${BOLD}PASS${NC}"
    EMOJI="🎉"
else
    STATUS="${RED}${BOLD}FAIL${NC}"
    EMOJI="📚"
fi

printf "${BOLD}║                                                              ║${NC}\n"
printf "${BOLD}║${NC}       Final Score:  ${BOLD}%3d / %3d${NC}   (%d%%)                       ${BOLD}║${NC}\n" "$EARNED" "$TOTAL" "$PERCENT"
printf "${BOLD}║${NC}       Status:      %b                                    ${BOLD}║${NC}\n" "$STATUS"
printf "${BOLD}║${NC}       Passing:     70 / 100                                ${BOLD}║${NC}\n"
printf "${BOLD}║                                                              ║${NC}\n"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"

echo ""
if [ "$EARNED" -ge 70 ]; then
    echo -e "  ${GREEN}${BOLD}$EMOJI  Congratulations! You passed the Month 1 Lab Exam.${NC}"
else
    NEEDED=$((70 - EARNED))
    echo -e "  ${RED}$EMOJI  You need ${BOLD}$NEEDED more point(s)${NC}${RED} to pass. Review and retry!${NC}"
fi

echo ""
echo -e "${DIM}  Graded at: $(date)${NC}"
echo -e "${DIM}  Tip: Run this script after a reboot to verify persistence.${NC}"
echo ""
