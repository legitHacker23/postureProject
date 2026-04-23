# PostureProject

A macOS posture-detection app that lives behind your MacBook's notch. Hover the notch for a live camera preview and posture status; after 15 seconds of sustained bad posture, a red light appears beside the notch and stays there until you fix it.

## Installing PostureProject

PostureProject isn't signed with an Apple Developer ID (this is a personal project and I'm not paying the $99/year for signing). macOS will flag it on first launch. It's safe — you can verify the source on GitHub — but you'll need to manually approve it once. Pick whichever method is easier.

### 1. Download and install

1. Download `PostureProject.dmg`.
2. Double-click to open it, then drag **PostureProject** into the **Applications** folder.
3. Eject the disk image.

### 2. First launch — bypass Gatekeeper (pick one method)

**Method A — System Settings (easiest):**
1. Double-click PostureProject in Applications. You'll see a warning that Apple can't check it for malicious software.
2. Click **Done** on the dialog.
3. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to the PostureProject message.
4. Confirm in the follow-up dialog. The app will launch.

**Method B — Terminal (one command):**
```
xattr -dr com.apple.quarantine /Applications/PostureProject.app
```
Then double-click the app as normal.

### 3. Grant camera permission

The app uses your webcam to track your posture. macOS will prompt for access the first time it launches; click **OK**. You can revoke access anytime in **System Settings → Privacy & Security → Camera**.

### 4. Using the app

- The app has no window and no Dock icon. It runs behind the notch (or at the top of the screen on non-notched Macs).
- Hover your mouse over the notch to see the camera preview and posture status.
- A red light appears to the left of the notch after 15 seconds of sustained bad posture; it turns green briefly when you fix it.
- To quit: click the figure icon in the menu bar (top-right) → **Quit PostureProject**.

## Requirements

- macOS 14 or later
- A built-in or external webcam

## Build from source

If you want to build it yourself instead of downloading the DMG:

1. Install Xcode from the Mac App Store.
2. Clone the repo and open `PostureProject.xcodeproj`.
3. Press ⌘R to run, or run `./build_dmg.sh` from the project root to produce a distributable `build/PostureProject.dmg`.

<img width="1192" alt="Screenshot 2025-05-24 at 2 02 54 PM" src="https://github.com/user-attachments/assets/05e2c90e-28b1-433a-bf13-3f8ba91d841a" />
<img width="1256" alt="Screenshot 2025-05-24 at 1 54 14 PM" src="https://github.com/user-attachments/assets/05c721bb-8327-4ff1-b173-31412a5bc45d" />
