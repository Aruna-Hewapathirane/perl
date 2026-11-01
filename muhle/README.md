<img width="654" height="774" alt="image" src="https://github.com/user-attachments/assets/f861afb9-fa65-444e-acfa-ccbda3564d2d" />

# Nine Men's Morris

A Nine Men's Morris game written in Perl with Gtk3.

## Installation

Install the dependencies:

- **Debian/Ubuntu:** `sudo apt install libgtk3-perl libcairo-perl`
- **Anywhere else:** `cpanm Gtk3 Cairo`

## Usage

```bash
perl morris.pl
```

## How to Play

- **Placing:** Each player puts down 9 pieces, White first.
- **Mills:** Three in a row removes an enemy piece. Pieces in a mill are protected unless every enemy piece is in one.
- **Moving:** Once all pieces are placed, slide a piece along a line to an adjacent empty point.
- **Flying:** A player down to 3 pieces can jump to any empty point.
- **Winning:** Reduce the opponent to 2 pieces, or leave them with no legal move.

## Interface

- **Controls:** Click to place, select, move, or remove.
- **Hints:** Green dots show where you can go. A yellow ring marks the selected piece, and red rings mark pieces you can remove.
- **Window:** The board resizes with the window, and the bar at the bottom shows how many pieces each side has in hand and on the board.
- **Computer opponent:** A checkbox lets you play against the computer as Black. It uses a simple heuristic that takes a mill when it can, blocks yours, and otherwise prefers open positions. It is beatable.

## Known Limitations

- Draws such as repeated positions are not detected.
- The computer opponent is heuristic-based rather than a full minimax search.
