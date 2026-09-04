# Passwort setzen — nur Authentication (nicht Firestore!)

Passwort für die App: **`Taxi2026!`**

---

## Schritt 1 — Seite öffnen

Klick: https://console.firebase.google.com/project/collectionshop-2854d/authentication/users

Du musst die Liste **„Nutzer“** sehen (nicht Firestore).

---

## Schritt 2 — Alten User löschen

1. Zeile **`fahrer@test.de`** finden  
2. Rechts **drei Punkte ⋮**  
3. **Nutzer löschen**  
4. Bestätigen  

Nicht „Passwort zurücksetzen“ wählen.

---

## Schritt 3 — Neu anlegen

1. Button **Nutzer hinzufügen**  
2. E-Mail: `fahrer@test.de`  
3. Passwort: `Taxi2026!`  
4. Speichern  

---

## Schritt 4 — UID kopieren

Neben dem neuen User steht eine lange **User-UID**.  
Kopieren und mit dieser vergleichen: `yWKhzlMHCPOaKAdqeuXjBtcLtB12`

- **Gleich** → weiter zu Schritt 6  
- **Anders** → Schritt 5

---

## Schritt 5 — Nur bei neuer UID (Firestore)

1. https://console.firebase.google.com/project/collectionshop-2854d/firestore/data  
2. Sammlung **`user`**  
3. **Dokument hinzufügen**  
4. Dokument-ID = **die neue User-UID** (einfügen)  
5. Felder:
   - `role` → string → `driver`
   - `email` → string → `fahrer@test.de`
   - `displayName` → string → `Testfahrer`
   - `isOnline` → boolean → `false`
6. Speichern  

Kein Feld `password` anlegen.

---

## Schritt 6 — App

1. E-Mail: `fahrer@test.de`  
2. Passwort: `Taxi2026!`  
3. **Einloggen**  

Erwartung: Home-Screen. Sonst Alert-Text / Screenshot schicken.

---

## Merksatz

| Ort | Was |
|-----|-----|
| **Authentication** | Passwort |
| **Firestore `user`** | nur `role: driver` usw. |
| **App** | gleiches Passwort wie in Authentication |
