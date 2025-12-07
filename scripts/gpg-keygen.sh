#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# GPG Keyset Generator for Yubikey
# ==========================================
# 
# Generates a master key + 3 subkeys:
#   - Master: Certification + Sign
#   - Sub 1: Encryption
#   - Sub 2: Signing
#   - Sub 3: Authentication (SSH)
#
# Best practice: Move subkeys to Yubikey,
#                keep master offline in safe
# ==========================================

# Check empty directory
if [ -n "$(ls -A)" ]; then
    echo "❌ Error: Must run in empty directory"
    echo "   Current directory contains files"
    exit 1
fi

# ==========================================
# USER INPUT
# ==========================================

echo "╔════════════════════════════════════════╗"
echo "║     GPG Keyset Generation              ║"
echo "╚════════════════════════════════════════╝"
echo ""

read -r -p "Full name: " NAME
read -r -p "Email: " EMAIL

# Validate email
if ! [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "❌ Invalid email format"
    exit 1
fi

# Expiration date (default: 3 years)
read -r -p "Expiration date [YYYY-MM-DD] (default: +3 years): " EXPIRY
if [ -z "$EXPIRY" ]; then
    EXPIRY=$(date -d "+3 years" +%Y%m%dT000000)
else
    EXPIRY="${EXPIRY//-/}T000000"
fi

# Master key expiration (longer)
MASTER_EXPIRY=$(date -d "+10 years" +%Y%m%dT000000)

echo ""
echo "Summary:"
echo "  Name: $NAME"
echo "  Email: $EMAIL"
echo "  Subkeys expire: $EXPIRY"
echo "  Master expires: $MASTER_EXPIRY"
echo ""
read -r -p "Continue? [y/N]: " confirm
[ "$confirm" != "y" ] && exit 0

# ==========================================
# PASSPHRASE (secure input)
# ==========================================

echo ""
echo "Enter passphrase for key protection"
echo "(min 20 characters recommended)"
stty -echo
read -r PASSPHRASE
stty echo
echo ""

if [ ${#PASSPHRASE} -lt 12 ]; then
    echo "⚠️  Warning: Passphrase too short (< 12 chars)"
    read -r -p "Continue anyway? [y/N]: " cont
    [ "$cont" != "y" ] && exit 0
fi

# ==========================================
# GNUPG HOME SETUP
# ==========================================

GNUPGHOME="$(pwd)/gnupghome"
export GNUPGHOME
mkdir -p "$GNUPGHOME"
chmod 0700 "$GNUPGHOME"

# Configure GPG for batch mode
cat > "$GNUPGHOME/gpg.conf" <<EOF
# Batch configuration
use-agent
pinentry-mode loopback
EOF

cat > "$GNUPGHOME/gpg-agent.conf" <<EOF
allow-loopback-pinentry
max-cache-ttl 60
default-cache-ttl 60
EOF

# ==========================================
# MASTER KEY GENERATION
# ==========================================

echo ""
echo "Generating master key (4096 RSA)..."
cat <<EOF | gpg --batch --generate-key
    Key-Type: RSA
    Key-Length: 4096
    Key-Usage: cert,sign
    Expire-Date: $MASTER_EXPIRY
    Name-Real: $NAME
    Name-Email: $EMAIL
    Passphrase: $PASSPHRASE
    %commit
EOF

FINGERPRINT=$(gpg --list-keys "$EMAIL" | grep -oE '[A-F0-9]{40}')
echo "✅ Master key: $FINGERPRINT"

# ==========================================
# SUBKEYS GENERATION
# ==========================================

echo ""
echo "Generating subkeys..."

# Encryption subkey
echo "$PASSPHRASE" | gpg --pinentry-mode loopback --batch --no-tty --yes --passphrase-fd 0 \
    --quick-add-key "$FINGERPRINT" rsa4096 encrypt "$EXPIRY"
echo "✅ Encryption subkey"

# Signing subkey
echo "$PASSPHRASE" | gpg --pinentry-mode loopback --batch --no-tty --yes --passphrase-fd 0 \
    --quick-add-key "$FINGERPRINT" rsa4096 sign "$EXPIRY"
echo "✅ Signing subkey"

# Authentication subkey (for SSH)
echo "$PASSPHRASE" | gpg --pinentry-mode loopback --batch --no-tty --yes --passphrase-fd 0 \
    --quick-add-key "$FINGERPRINT" rsa4096 auth "$EXPIRY"
echo "✅ Authentication subkey"

# ==========================================
# EXPORTS
# ==========================================

echo ""
echo "Exporting keys..."

# Public key
gpg --export --armor > gpg-pubkeys.asc
echo "✅ Public keys → gpg-pubkeys.asc"

# SSH public key
gpg --export-ssh-key "$EMAIL" > ssh-pubkey.txt
echo "✅ SSH pubkey → ssh-pubkey.txt"

# Fingerprint & ID
echo "$FINGERPRINT" > gpg-fingerprint.txt
echo "${FINGERPRINT: -16}" > gpg-keyid.txt
echo "✅ Fingerprint → gpg-fingerprint.txt"

# Private keys (ENCRYPTED backup)
echo "$PASSPHRASE" | gpg --no-tty --yes --passphrase-fd 0 \
    --export-secret-key --armor --batch --pinentry-mode loopback "$EMAIL" > gpg-privkeys.asc
echo "✅ Private keys → gpg-privkeys.asc"

# GNUPGHOME archive (for restoration)
tar -C "$GNUPGHOME" --exclude='S.*' --exclude='*.conf' -czf gnupghome.tar.gz .
echo "✅ GNUPGHOME → gnupghome.tar.gz"

# Revocation certificate
echo "$PASSPHRASE" | gpg --no-tty --yes --passphrase-fd 0 \
    --batch --pinentry-mode loopback \
    --gen-revoke "$FINGERPRINT" > revocation-certificate.asc
echo "✅ Revocation → revocation-certificate.asc"

# ==========================================
# SUMMARY
# ==========================================

echo ""
echo "╔════════════════════════════════════════╗"
echo "║     Generation Complete!               ║"
echo "╚════════════════════════════════════════╝"
echo ""
gpg --list-keys "$EMAIL"
echo ""
gpg --list-secret-keys "$EMAIL"
echo ""

# ==========================================
# NEXT STEPS INSTRUCTIONS
# ==========================================

cat > NEXT_STEPS.txt <<EOF
╔════════════════════════════════════════════════╗
║     GPG Keys Generated - Next Steps            ║
╚════════════════════════════════════════════════╝

Key Information:
  Email: $EMAIL
  Fingerprint: $FINGERPRINT
  Short ID: ${FINGERPRINT: -16}

Generated files:
  ✅ gpg-pubkeys.asc          - Public keys (share this)
  ✅ gpg-privkeys.asc         - Private keys (SECURE!)
  ✅ ssh-pubkey.txt           - SSH public key
  ✅ gnupghome.tar.gz         - Full GNUPGHOME backup
  ✅ revocation-certificate.asc - Emergency revoke

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SECURITY WORKFLOW:

1. BACKUP MASTER KEY (OFFLINE!)
   
   # Export master to paper
   paperkey --secret-key gpg-privkeys.asc --output master-paper.txt
   
   # Print & store in safe
   # Also backup: gnupghome.tar.gz + revocation cert

2. MOVE SUBKEYS TO YUBIKEY

   # Insert Yubikey
   gpg --edit-key $FINGERPRINT
   
   # In GPG prompt:
   > key 1       # Select encryption subkey
   > keytocard   # Choose slot 2 (Encryption)
   > key 1       # Deselect
   > key 2       # Select signing subkey
   > keytocard   # Choose slot 1 (Signing)
   > key 2       # Deselect
   > key 3       # Select authentication subkey
   > keytocard   # Choose slot 3 (Authentication)
   > save

3. VERIFY YUBIKEY

   gpg --card-status
   
   # Should show your keys in slots

4. PUBLISH PUBLIC KEY

   # To keyserver
   gpg --send-keys $FINGERPRINT
   
   # Or manually share: gpg-pubkeys.asc

5. CONFIGURE SSH

   # Add to ~/.bashrc or ~/.zshrc:
   export GPG_TTY=\$(tty)
   export SSH_AUTH_SOCK=\$(gpgconf --list-dirs agent-ssh-socket)
   gpgconf --launch gpg-agent
   
   # Enable SSH support in GPG agent:
   echo "enable-ssh-support" >> ~/.gnupg/gpg-agent.conf
   
   # Add public key to servers:
   cat ssh-pubkey.txt >> ~/.ssh/authorized_keys

6. DELETE THIS DIRECTORY (after backup!)

   # Once subkeys are on Yubikey and master is backed up:
   cd ..
   rm -rf "$(pwd)"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TESTING:

# Test encryption
echo "test" | gpg --encrypt --recipient $EMAIL | gpg --decrypt

# Test signing
echo "test" | gpg --clearsign

# Test SSH (after Yubikey setup)
ssh-add -L  # Should show your GPG auth key

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  IMPORTANT SECURITY NOTES:

1. NEVER share gpg-privkeys.asc or gnupghome.tar.gz
2. Store backups encrypted on multiple locations
3. Keep revocation certificate separate from keys
4. Master key should NEVER touch internet-connected machine
5. Use Yubikey for daily operations

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

cat NEXT_STEPS.txt

echo ""
echo "📄 Instructions saved to: NEXT_STEPS.txt"
echo ""
echo "⚠️  WARNING: This directory contains your PRIVATE KEYS!"
echo "   Back them up securely, then DELETE this directory"
echo ""
