<img width="654" height="774" alt="image" src="https://github.com/user-attachments/assets/f861afb9-fa65-444e-acfa-ccbda3564d2d" />

To install the dependencies and start it:

Debian/Ubuntu: sudo apt install libgtk3-perl libcairo-perl
Anywhere else: cpanm Gtk3 Cairo
Run: perl morris.pl

How it plays

Placing: each player puts down 9 pieces, White first.
Mills: three in a row removes an enemy piece. Pieces in a mill are protected unless every enemy piece is in one.
Moving: once all pieces are placed, you slide a piece along a line to an adjacent empty point.
Flying: a player down to 3 pieces can jump to any empty point.
Winning: reduce the opponent to 2 pieces, or leave them with no legal move.

Interface

Controls: click to place, select, move, or remove.
Hints: green dots show where you can go. A yellow ring marks the selected piece, and red rings mark pieces you can remove.
Window: it resizes with the window, and the bar at the bottom shows how many pieces each side has in hand and on the board.
Computer opponent: there is a checkbox to play against it as Black. It is a simple heuristic that takes a mill when it can, blocks yours, and otherwise prefers open positions. It is beatable.
