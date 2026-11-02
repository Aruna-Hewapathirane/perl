<table>
  <tr>
    <td><img src="<img width="362" height="708" alt="image" src="https://github.com/user-attachments/assets/1f626523-d9e9-4398-b0ce-96c6e860df79" />" width="300"></td>
    <td width="40"></td>
    <td><img src="<img width="362" height="708" alt="image" src="https://github.com/user-attachments/assets/cf789d2a-5ab4-4e4d-9621-8deaf762e28e" />" width="300"></td>
  </tr>
</table>






# Mastermind

A classic Mastermind code-breaking game written in Perl with GTK3 and Cairo.

## Setup

Install the dependencies and run the game:

```bash
sudo apt install libgtk3-perl libcairo-perl     # Debian/Ubuntu
# or: cpanm Gtk3 Cairo
perl mastermind.pl
```

## How to Play

- The computer picks a secret code of 4 pegs from 6 colors. Colors can repeat.
- You get 10 attempts to crack the code.
- After each guess you get feedback pegs:
  - **Black peg**: right color in the right spot.
  - **White peg**: right color in the wrong spot.
- The secret code stays hidden until you win or run out of tries.
- Each peg also shows its number, so colors can be told apart without relying on hue alone.

## Controls

| Action | Mouse | Keyboard |
| --- | --- | --- |
| Fill the next slot | Click a color in the palette | `1`–`6` |
| Remove a peg | Click a filled slot in the active row, or the **Undo** button | `Backspace` |
| Submit a guess | **Submit** button | `Enter` |
| Start a new game | **New Game** button | |

## Implementation Notes

- The whole board is drawn with Cairo on a single `DrawingArea`.
- The buttons and status line are ordinary GTK widgets.
- The scoring routine counts black pegs first, then matches the leftover colors for white pegs, so repeated colors are scored correctly.

## Configuration

The constants at the top of `mastermind.pl` control the game:

| Constant | Purpose |
| --- | --- |
| `PEGS` | Code length |
| `MAXTRIES` | Number of attempts |
| `@COLORS` | Color list |

To make the game harder, raise `PEGS` or add colors.

> **Note:** The layout is fixed-size, so using more than about 5 pegs or 6 colors requires adjusting the layout constants.
