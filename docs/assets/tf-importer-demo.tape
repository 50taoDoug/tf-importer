# Optional VHS source for generating a 30–60 second GIF from the same
# fictional demo. The tape executes only a fixed-output simulator that never
# executes AWS, Terraform, Make, or user-provided input.

Output docs/assets/tf-importer-demo.gif
Set Shell "bash"
Set FontSize 18
Set Width 960
Set Height 540
Set TypingSpeed 30ms
Set Theme {"name":"tf-importer","black":"#0d1117","brightBlack":"#8b949e","green":"#3fb950","brightGreen":"#3fb950","blue":"#58a6ff","brightBlue":"#58a6ff","yellow":"#d29922","brightYellow":"#d29922","white":"#c9d1d9","brightWhite":"#f0f6fc","red":"#f85149","brightRed":"#f85149","magenta":"#bc8cff","brightMagenta":"#bc8cff","cyan":"#39c5cf","brightCyan":"#39c5cf","background":"#0d1117","foreground":"#c9d1d9","selectionBackground":"#264f78","cursorAccent":"#0d1117"}

Sleep 1s
Type "./docs/assets/tf-importer-demo.sh"
Enter
Sleep 36s
