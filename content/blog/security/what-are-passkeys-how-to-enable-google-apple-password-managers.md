---
title: "What Are Passkeys? How to Enable Them on Google, Apple, and Password Managers (2025 Guide)"
description: "Passkeys are phishing-resistant, passwordless logins built on FIDO2/WebAuthn. Learn how they work, why they beat SMS 2FA, how to enable them on Google and Apple, and how to use them with 1Password and Bitwarden."
date: 2025-08-22T10:00:00+07:00
publishDate: 2025-08-22T10:00:00+07:00
draft: false
tags: ["Security", "Passkeys", "FIDO2", "WebAuthn", "Account Security"]
slug: "what-are-passkeys-how-to-enable-google-apple-password-managers"
keywords: ["passkeys", "what are passkeys", "enable passkeys", "FIDO2", "WebAuthn", "passwordless login", "google passkeys", "apple passkeys", "bitwarden passkeys", "1password passkeys", "account security", "phishing"]
url: "/2025/08/what-are-passkeys-how-to-enable-google-apple-password-managers.html"
translationKey: "passkeys-2025"
disable_comments: false
ad_channel: "passkeys"
faq:
  - question: "Can I use passkeys across different devices and platforms (iPhone to Windows)?"
    answer: "Yes, but it depends on where you store your passkeys. Platform-bound passkeys (iCloud Keychain, Google Password Manager) sync only within their ecosystems. For cross-platform compatibility, use a password manager that supports passkeys like 1Password, Bitwarden, or Proton Pass--they work on iOS, Android, Windows, macOS, and Linux. These managers sync passkeys across all your devices regardless of platform, giving you seamless access everywhere."
  - question: "What happens to my passkeys if I lose my phone or switch devices?"
    answer: "If passkeys are synced via iCloud Keychain (Apple), Google Password Manager, or a password manager (1Password/Bitwarden), they're automatically available on your new device after signing in. For unsynced local passkeys, you'll lose access unless you registered backup authentication methods (additional passkey on another device, security key, or password fallback). Always enable sync and register at least two passkeys or backup methods for critical accounts."
  - question: "Are passkeys better than using a password manager with strong passwords and 2FA?"
    answer: "Passkeys offer stronger phishing resistance because they're cryptographically bound to the correct domain--they can't be used on fake lookalike sites. Password managers + strong passwords + TOTP/2FA are very secure, but users can still be tricked into entering credentials on phishing pages. Passkeys eliminate that risk entirely. Ideally, use a password manager that supports both passkeys (for sites that offer them) and strong passwords + 2FA (for sites that don't). This gives you maximum security and compatibility."
  - question: "Do I still need a hardware security key if I use passkeys?"
    answer: "For most users, synced passkeys from Google, Apple, or a password manager provide excellent security. However, hardware security keys (YubiKey, Titan) offer additional benefits: they're offline, can't be remotely compromised, work as reliable backup authentication, and some organizations require them for compliance. For critical accounts (email, domain registrar, financial, admin panels), keeping at least one hardware key as a backup is highly recommended even if you primarily use passkeys."
  - question: "Can passkeys be hacked or stolen like passwords?"
    answer: "Passkeys are much harder to compromise than passwords. The private key never leaves your device or password manager's encrypted storage, and signatures only work on the correct domain. An attacker would need to compromise your device (OS/browser) or password manager account (protected by master password + biometrics + 2FA) to steal passkeys. In contrast, passwords can be phished, guessed, intercepted, or leaked from breached databases. Keep your device/manager secure with updates, strong master password, and 2FA to maximize passkey protection."
  - question: "Which websites and apps currently support passkeys in 2025?"
    answer: "Major platforms supporting passkeys include Google (Gmail, Drive), Apple (iCloud), Microsoft (Outlook, Azure), PayPal, Amazon, eBay, GitHub, 1Password, Shopify, Best Buy, and many others. Adoption is accelerating--banks, email providers, e-commerce sites, and developer platforms are rolling out passkey support continuously. Check your account's security settings for 'passkey', 'passwordless', or 'FIDO2' options. For the latest list, visit passkeys.directory or check individual service security documentation."
---



Passkeys are increasingly supported across major platforms. They enable fast, convenient logins without passwords and are resistant to phishing. No more weak passwords or OTP codes hijacked via SIM swaps. This guide explains how passkeys work, compares them with legacy 2FA, and shows how to enable them on Google and Apple or use them with password managers like 1Password and Bitwarden.

## Summary: What Is a Passkey?

A passkey is a passwordless credential based on FIDO2/WebAuthn. Instead of typing a shared secret, you prove possession of a private cryptographic key securely stored on your device (or in a compatible password manager). When you log in, the site/app sends a challenge that only your private key can sign. The server verifies the signature with the public key you registered. No shared secret travels over the network.

In practice:
- No password transmission--only per‑site cryptographic signatures.
- Phishing‑resistant--signatures are bound to the real origin.
- More convenient--use Face/Touch ID or your device PIN to approve.

## Why It’s Safer Than Passwords and SMS 2FA

- Phishing resistance: Traditional passwords/managers can be tricked by look‑alike domains; passkeys can’t. The challenge only works on the correct origin.
- No SIM‑swap risk: SMS codes can be intercepted or diverted; passkeys don’t rely on SMS.
- Not guessable/brute‑forceable: They’re cryptographic keys, not words.
- Lower breach impact: Sites store public keys, not secrets. A database leak alone won’t let attackers sign in.

Caveat: Passkeys aren’t magic. A compromised device still puts you at risk. Keep your OS, browser, and extensions clean.

## How to Enable Passkeys

Menus vary by OS/browser version; the flow is similar everywhere.

### Google (Android/Chrome/Google Password Manager)
1. Go to `myaccount.google.com` > Security > Passkeys.
2. Click “Create a passkey” and approve with biometrics.
3. On other websites that support passkeys, choose “Use passkey” to register/login.
4. Sync: Your passkeys are stored in Google Password Manager and available on devices signed in to your Google account (protected by local biometrics/PIN).

### Apple (iCloud Keychain on iOS/macOS/Safari)
1. Ensure iCloud Keychain is enabled: Settings > iCloud > Passwords and Keychain.
2. When a site offers passkeys, Safari will prompt to save a passkey.
3. Next logins are approved with Face ID/Touch ID.
4. End‑to‑end encrypted sync via iCloud across your Apple devices.

### 1Password
1. Update to the latest 1Password and enable passkey support in the app/extension.
2. When a site offers passkeys, choose to save it in 1Password.
3. Future logins can be approved via 1Password--no password required.
4. Benefits: cross‑platform, secure sharing for families/teams, admin policies for orgs.

### Bitwarden
1. Update Bitwarden and enable passkey support in the extension/app.
2. Save passkeys when registering/enabling them on supported sites.
3. Approve future logins using Bitwarden with local biometrics/PIN.
4. Benefits: open‑source, cost‑effective, organization features.

Tip: If “Create/Use a passkey” doesn’t appear, check the site’s account security settings. Support is expanding--banks, email providers, marketplaces, and developer platforms are rolling it out.

## How It Works (The Short Version)

On registration, your device creates a public/private key pair and registers the public key with the site. On login, the site sends a challenge that your device signs with the private key after local verification (biometrics/PIN). The browser enforces origin binding so signatures don’t work on fake domains. That property provides phishing resistance.

## Limitations and How to Mitigate Them

- Lost/replaced device: Ensure sync is enabled (iCloud/Google/manager) and keep recovery methods (backup codes) for critical accounts.
- Compatibility: Some sites don’t support passkeys yet--keep a strong password + app‑based 2FA or a security key as fallback.
- Mixed ecosystems: If you use Apple + Windows + Android, a passkey‑capable manager (1Password/Bitwarden/Proton Pass) often provides the smoothest experience.
- Travel/emergency access: Keep at least one hardware security key as a break‑glass option for email, domain registrar, banking, and cloud.

## Migration Strategy: Practical Priorities

Prioritize high‑value accounts first--the ones attackers target most and the ones that would most harm your brand/SEO if compromised.

1) Secure critical accounts first:
   - Primary email (Gmail/iCloud/Outlook)
   - Cloud storage (Google Drive/iCloud/OneDrive)
   - Banking/fintech
   - Developer, domain/DNS, and hosting control panels

2) Enable passkeys and keep app‑based 2FA (TOTP) as backup
   - Avoid SMS where possible. Use a FIDO2 hardware key for mission‑critical accounts.

3) Hygiene and audits
   - Remove weak/duplicate passwords. Run your manager’s vault health check.
   - Revoke unknown sessions/devices and retire risky recovery methods (old SMS).

4) Team education (for orgs)
   - Standardize on passkeys + authenticator + security keys.
   - Teach staff to spot look‑alike domains, OAuth consent scams, and QR phishing.

## Quick FAQ

**Do I still need passwords?**
For many sites, yes--as fallback. Increasingly, services allow passkey‑only. Keep a unique, strong fallback where required.

**Are passkeys safe if my phone is stolen?**
Passkeys are protected behind device biometrics/PIN. Enable remote wipe and rotate critical credentials if a device is lost.

**How are passkeys different from TOTP?**
TOTP sits on top of passwords and can be entered on phishing sites. Passkeys remove passwords and bind authentication to the real domain.

**Do I need a hardware key?**
Highly recommended for critical accounts as a robust backup, but not mandatory for every account.

## Getting Started

- Enable passkeys on your Google/Apple account.
- Turn on passkey support in 1Password or Bitwarden (if you use them).
- Add passkeys to your primary email, domain registrar, and work platforms.
- Store recovery codes offline. Add one hardware key if possible.
- Phase out SMS 2FA where a stronger alternative exists (auth app/security key).

## Key Takeaways

Passkeys provide a practical improvement: fast, convenient, and phishing‑resistant logins. Start with your most important accounts, enable trustworthy sync, set up recovery paths, and keep strong 2FA as backup. You get shorter logins, lower risk, and less password‑management overhead--without the weak links of traditional passwords.
