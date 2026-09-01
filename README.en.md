# Homowarden

[中文](README.md) | [English](README.en.md)

Homowarden is an unofficial Bitwarden client for HarmonyOS, written in ArkTS. It runs on phones, tablets, and PCs, works with official and self-hosted servers, and keeps vault data end-to-end encrypted.

**Note:** Keys are stored in the system asset store and are **not** removed when the app is uninstalled. Sign out from Settings before uninstalling.

Homowarden is available on Huawei AppGallery:

<a href="https://appgallery.huawei.com/app/detail?id=com.dreamist.homowarden&channelId=SHARE&source=appshare" target="_blank"><img src="./Huawei_AppGallery_white_badge_EN.png" width="300" /></a>

## Features

### Account and authentication

- Supports `bitwarden.com`, `bitwarden.eu`, and self-hosted Bitwarden servers
- Supports two-step verification and new-device email verification

<img src="pictures/06-server-types-pc-en.png" alt="Server types on PC" width="50%" />

### Vault

- Syncs the vault from the server into a local encrypted database
- Supports logins, secure notes, cards, and identities
- Supports create, view, edit, delete, restore from trash, and permanent delete
- Supports favorites, custom fields, multiple URIs, and master-password re-prompt
- Supports type, favorite, and trash filters, plus keyword search
- Supports quick copy for username, password, TOTP, and other common fields

<img src="pictures/01-cross-platform-sync-pc-en.png" alt="Vault on PC" width="50%" />

<img src="pictures/05-custom-fields-pc-en.png" alt="Custom fields on PC" width="50%" />

### TOTP

- Shows live codes in item details and in a dedicated list
- Parses `otpauth://` links and extracts secrets
- Supports QR scanning
- On 2-in-1 devices, supports importing a TOTP QR code from an image

<img src="pictures/03-totp-pc-en.png" alt="TOTP on PC" width="50%" />

### Password and username generator

- Generates passwords with the system secure random source
- Configurable length, upper/lowercase letters, digits, symbols, and minimum counts
- Supports random-word usernames and email aliases
- Can generate and fill values while adding or editing a login
- Saves generator history, with copy, single-item delete, and clear all

<img src="pictures/04-generator-pc-en.png" alt="Generator on PC" width="50%" />

### Devices and interaction

- Runs on phones, tablets, and PCs
- Bottom navigation on phones, side rail on wide screens
- Split list/detail layout on wide screens
- Chinese and English UI, following the system language
- PC tray icon and context menus

<img src="pictures/02-phone-tablet-pc-en.png" alt="Phone, tablet, and PC" width="50%" />

### Security

- Supports PBKDF2 / Argon2id
- Stores sensitive data in the system asset store
- Master-password unlock, biometric unlock, and auto-lock
- Screenshot blocking and anti-peep protection when the device supports them
- Clears the local vault, generator history, and credentials on sign-out
- Redacts tokens, passwords, and other secrets from logs

### Sure2Share

- Strips tracking parameters from common share links
- Copy the full result or the link only
- Saves share history, with search, multi-select, and batch delete

## Not supported yet

- Autofill
- Password health checks
- Folders, organizations, attachments, and other Bitwarden features
- Vault import/export and backup/restore

## Project structure

```text
entry/src/main/ets/
├── component/          # UI components
├── domain/             # display mapping
├── entryability/       # app entry Ability
├── entrybackupability/ # backup extension
├── localization/       # locale state and i18n helpers
├── model/              # data models
├── network/            # Bitwarden APIs
├── pages/              # pages
├── utils/              # crypto, database, assets, link parsing
└── viewmodel/          # page state and business logic
```

## Project dependencies

- ArkTS / ArkUI
- `@ohos/axios`
- `@huozhiniao/argon2`
- `@abner/datastore`
- `@nzy/logger`

## Notes

- This is an unofficial HarmonyOS client for Bitwarden
- It has not been independently audited and should not be your only copy of vault data
- Sensitive data lives in the system asset store; sign out before uninstalling
- Self-hosted servers usually need a valid HTTPS setup

## License

This project is licensed under the MIT License. See the LICENSE file for details.
