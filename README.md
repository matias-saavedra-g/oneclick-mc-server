# 1️⃣🖱 One-Click Auto Deploying Minecraft Server ⛏

This batch script is designed to manage a Minecraft server, including updating, backing up, starting, and restarting the server. Let's break down its functionality step by step. [^1]

# ⌨️ Console Setup

The script begins by setting up the console environment. It sets the window title to "MT Server" and changes the console color scheme to a blue background with white text.

# ⏬ Update Section

The script then checks if the server.jar file exists. If it doesn't, it proceeds to download the latest version. If the file does exist, it fetches the latest server version from the Mojang website and compares it with the current version stored in a specific directory. The user is prompted to decide whether to upgrade the server. If the user agrees, the old server.jar file is deleted, and the new version is downloaded.

# 🧰 Backup Section

Next, the script checks if the world directory exists. If it does, it creates a backup of this directory using 7zip. The backup file is named with the current date and time to ensure uniqueness and easy identification.

# 🏁 Start Section

The script then provides functionality to start the Minecraft server. It uses specific Java options to allocate memory and optimize garbage collection.

# 🔁 Restart Section

The script includes a restart mechanism. It prompts the user to decide whether to restart the server. If the user agrees, the script jumps back to the start section to restart the server.

# 🔚 Exit Section

Finally, the script provides an option to exit the server. It informs the user that the server is exiting, waits for 2 seconds, and then exits the script.

Overall, this batch script automates several key tasks for managing a Minecraft server, making it easier for the user to keep the server updated, backed up, and running smoothly.

[^1]: Thank you Copilot for this description.