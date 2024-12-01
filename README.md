# Bubble note

Is a tiny utility to help me remember stuff. I tend to often forget that my todo lists even exist themselves, and so they're basically useless to me.

This is my personal solution to this problem. I use the terminal/shell all the time, every day, and so this utility allows me to manage a list which
is shown each time I open a new shell. The foreground colour of the text and the emojis on the header change every day to keep my monkey brain from
phasing it out of existence (I can't use postinotes or signs to remind me things I eventually look right through them).

![Screenshot 2024-11-29 17 09 07](https://github.com/user-attachments/assets/ded607c5-32bb-4fc6-a4a4-ff59428e3389)
_________________
![Screenshot 2024-12-01 17 53 38](https://github.com/user-attachments/assets/a145c59f-b92b-4958-baf4-ae4086cb6e18)


### Example usage:

Add new reminder
`bn add reminder "Write README for bubble-note"`

List all current reminders
`bn list reminders`

Remove reminder by ID
`bn remove reminder 1`

I have my fish config set to run `bn list reminders` on shell init.
