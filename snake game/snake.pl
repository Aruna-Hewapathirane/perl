#!/usr/bin/env perl
use strict;
use warnings;
use Gtk3 -init;
use Glib qw(TRUE FALSE);

# --- GAME CONFIGURATION ---
my $GRID_SIZE  = 20;  # Size of each grid block in pixels
my $GRID_WIDTH = 25;  # Number of horizontal blocks (500px total)
my $GRID_HEIGHT= 20;  # Number of vertical blocks (400px total)
my $SPEED_MS   = 120; # Game speed update interval (lower means faster)

# --- GAME STATE VARIABLES ---
# The snake is an array of hash coordinates. Index 0 is the snake's head.
my @snake = ( {x => 10, y => 10}, {x => 10, y => 11}, {x => 10, y => 12} );
my %apple = ( x => 5, y => 5 );

# Current direction of travel: 'up', 'down', 'left', 'right'
my $dir = 'up';
my $game_over = 0;
my $score = 0;

# --- MAIN WINDOW SETUP ---
my $window = Gtk3::Window->new('toplevel');
$window->set_title("Perl GTK3 Snake Game - Score: 0");
$window->set_resizable(FALSE);
$window->signal_connect(destroy => sub { Gtk3::main_quit() });

# Vertical container to hold drawing area and feedback text
my $vbox = Gtk3::Box->new('vertical', 0);
$window->add($vbox);

# The graphics rendering area
my $area = Gtk3::DrawingArea->new();
$area->set_size_request($GRID_WIDTH * $GRID_SIZE, $GRID_HEIGHT * $GRID_SIZE);
$vbox->pack_start($area, TRUE, TRUE, 0);

# --- KEYBOARD EVENT HANDLER ---
$window->signal_connect('key-press-event' => sub {
    my ($widget, $event) = @_;
    my $key = $event->keyval;

    # Map keyboard inputs (Arrow keys & WASD keys) while preventing 180-degree self-collisions
    if (($key == 65362 || $key == 119) && $dir ne 'down')  { $dir = 'up';    } # Up Arrow / W
    if (($key == 65364 || $key == 115) && $dir ne 'up')    { $dir = 'down';  } # Down Arrow / S
    if (($key == 65361 || $key == 97)  && $dir ne 'right') { $dir = 'left';  } # Left Arrow / A
    if (($key == 65363 || $key == 100) && $dir ne 'left')  { $dir = 'right'; } # Right Arrow / D

    # Restart game if Spacebar is pressed during Game Over screen
    if ($key == 32 && $game_over) {
        @snake = ( {x => 10, y => 10}, {x => 10, y => 11}, {x => 10, y => 12} );
        $dir = 'up';
        $score = 0;
        $game_over = 0;
        spawn_apple();
        $window->set_title("Perl GTK3 Snake Game - Score: $score");
    }
    return FALSE;
});

# --- CANVAS RENDERING (CAIRO DRAW ENGINE) ---
$area->signal_connect('draw' => sub {
    my ($widget, $cr) = @_;

    # 1. Clear and color the background (Dark Charcoal Slate)
    $cr->set_source_rgb(0.12, 0.12, 0.14);
    $cr->paint();

    if ($game_over) {
        # Render Game Over text overlay
        $cr->set_source_rgb(0.9, 0.2, 0.2);
        $cr->select_font_face("Sans", 'normal', 'bold');
        $cr->set_font_size(24);
        $cr->move_to(130, 180);
        $cr->show_text("GAME OVER");

        $cr->set_source_rgb(0.8, 0.8, 0.8);
        $cr->set_font_size(14);
        $cr->move_to(110, 220);
        $cr->show_text("Press SPACEBAR to play again.");
        return FALSE;
    }

    # 2. Draw Apple (Crimson Red Red)
    $cr->set_source_rgb(0.85, 0.24, 0.24);
    $cr->rectangle($apple{x} * $GRID_SIZE + 1, $apple{y} * $GRID_SIZE + 1, $GRID_SIZE - 2, $GRID_SIZE - 2);
    $cr->fill();

    # 3. Draw Snake (Emerald Green with a brighter head accent)
    for my $i (0 .. $#snake) {
        if ($i == 0) {
            $cr->set_source_rgb(0.24, 0.82, 0.44); # Brighter Head
        } else {
            $cr->set_source_rgb(0.18, 0.68, 0.35); # Body segments
        }
        $cr->rectangle($snake[$i]{x} * $GRID_SIZE + 1, $snake[$i]{y} * $GRID_SIZE + 1, $GRID_SIZE - 2, $GRID_SIZE - 2);
        $cr->fill();
    }
    return FALSE;
});

# --- GENERATE RANDOM APPLE POSITION ---
sub spawn_apple {
    $apple{x} = int(rand($GRID_WIDTH));
    $apple{y} = int(rand($GRID_HEIGHT));
}
spawn_apple(); # Initial apple placement

# --- ENGINE TICK TIMEOUT (GAME LOOP STEPS) ---
Glib::Timeout->add($SPEED_MS, sub {
    return FALSE if $game_over;

    # Calculate where the head is shifting next
    my $head = $snake[0];
    my $new_head = { x => $head->{x}, y => $head->{y} };

    if    ($dir eq 'up')    { $new_head->{y}--; }
    elsif ($dir eq 'down')  { $new_head->{y}++; }
    elsif ($dir eq 'left')  { $new_head->{x}--; }
    elsif ($dir eq 'right') { $new_head->{x}++; }

    # Wall Collision Logic check
    if ($new_head->{x} < 0 || $new_head->{x} >= $GRID_WIDTH || $new_head->{y} < 0 || $new_head->{y} >= $GRID_HEIGHT) {
        $game_over = 1;
        $area->queue_draw();
        return TRUE;
    }

    # Self-Collision Logic check
    for my $segment (@snake) {
        if ($new_head->{x} == $segment->{x} && $new_head->{y} == $segment->{y}) {
            $game_over = 1;
            $area->queue_draw();
            return TRUE;
        }
    }

    # Advance head position
    unshift @snake, $new_head;

    # Apple Collision check
    if ($new_head->{x} == $apple{x} && $new_head->{y} == $apple{y}) {
        $score += 10;
        $window->set_title("Perl GTK3 Snake Game - Score: $score");
        spawn_apple();
    } else {
        pop @snake; # Remove tail block if no food eaten (keeps length constant)
    }

    $area->queue_draw(); # Trigger a screen redraw event loop step
    return TRUE;
});

# Fire up window display loop
$window->show_all();
Gtk3::main();

