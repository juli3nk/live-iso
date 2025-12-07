#!/usr/bin/env bash

echo "╔════════════════════════════════════════╗"
echo "║   Yubikey Configuration Assistant      ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check if Yubikey is present
if ! ykman list | grep -q "YubiKey"; then
  echo "❌ No Yubikey detected"
  echo ""
  echo "Please:"
  echo "  1. Insert your Yubikey"
  echo "  2. Wait 2 seconds"
  echo "  3. Run this script again"
  exit 1
fi

echo "✅ Yubikey detected"
echo ""
ykman info
echo ""

# Main menu
echo "What do you want to do?"
echo ""
echo "1) Configure FIDO2"
echo "2) Configure PIV (smart card)"
echo "3) Configure OTP"
echo "4) Reset Yubikey (⚠️  DANGER)"
echo "5) Display information only"
echo "0) Cancel"
echo ""
read -r -p "Choice: " choice

case $choice in
  1)
    echo ""
    echo "=== FIDO2 Configuration ==="
    echo ""
    echo "Setting FIDO2 PIN..."
    ykman fido access change-pin
    echo ""
    echo "✅ FIDO2 configured"
    ;;

  2)
    echo ""
    echo "=== PIV Configuration ==="
    echo ""
    echo "⚠️  This will:"
    echo "  - Generate a new PIV key"
    echo "  - Set a PIN (default: 123456)"
    echo "  - Set a PUK (default: 12345678)"
    echo ""
    read -r -p "Continue? (y/N): " confirm

    if [ "$confirm" = "y" ]; then
      echo ""
      echo "Generating PIV key..."
      ykman piv keys generate 9a /tmp/pubkey.pem
      echo ""
      echo "Creating self-signed certificate..."
      ykman piv certificates generate -s "Yubikey PIV" 9a /tmp/pubkey.pem
      echo ""
      echo "✅ PIV configured"
      echo ""
      echo "Default PIN: 123456"
      echo "Default PUK: 12345678"
      echo ""
      echo "⚠️  Change these values with:"
      echo "   ykman piv access change-pin"
      echo "   ykman piv access change-puk"
      rm -f /tmp/pubkey.pem
    fi
    ;;

  3)
    echo ""
    echo "=== OTP Configuration ==="
    echo ""
    ykman otp info
    echo ""
    echo "Available slots:"
    echo "  1) Short press"
    echo "  2) Long press (3 sec)"
    echo ""
    read -r -p "Configure slot (1/2): " slot

    if [ "$slot" = "1" ] || [ "$slot" = "2" ]; then
      echo ""
      echo "Generating OTP configuration..."
      ykman otp chalresp --touch --generate "$slot"
      echo ""
      echo "✅ OTP slot $slot configured"
    fi
    ;;

  4)
    echo ""
    echo "⚠️  ⚠️  ⚠️  DANGER ⚠️  ⚠️  ⚠️"
    echo ""
    echo "This will ERASE ALL DATA on the Yubikey!"
    echo ""
    read -r -p "Type 'YES' to confirm: " confirm

    if [ "$confirm" = "YES" ]; then
      echo ""
      echo "Resetting FIDO2..."
      ykman fido reset
      echo ""
      echo "Resetting PIV..."
      ykman piv reset
      echo ""
      echo "Resetting OTP..."
      ykman otp delete 1 --force || true
      ykman otp delete 2 --force || true
      echo ""
      echo "✅ Yubikey reset complete"
    else
      echo "Reset cancelled"
    fi
    ;;

  5)
    echo ""
    echo "=== Yubikey Information ==="
    echo ""
    ykman info
    echo ""
    echo "=== FIDO2 ==="
    ykman fido info || echo "FIDO2 not configured"
    echo ""
    echo "=== PIV ==="
    ykman piv info || echo "PIV not configured"
    echo ""
    echo "=== OTP ==="
    ykman otp info || echo "OTP not configured"
    ;;

  0)
    echo "Cancelled"
    exit 0
    ;;

  *)
    echo "Invalid choice"
    exit 1
    ;;
esac

echo ""
