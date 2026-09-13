#!/usr/bin/env perl
use strict;
use warnings;
use Tk;

# --- Game Configuration ---
my $canvas_w   = 600;
my $canvas_h   = 400;
my $paddle_w   = 80;
my $paddle_h   = 15;
my $ball_r     = 8;     

# Ball speed and position
my $ball_x     = 300;
my $ball_y     = 250;
my $dx         = 3;     
my $dy         = -3;    

# --- Score Tracking Variables ---
my $score      = 0;
my $points_per_brick = 10;

# Create Main Window
my $mw = MainWindow->new(-title => "Perl Breakout with Score");

# Create Game Canvas
my $canvas = $mw->Canvas(
    -width  => $canvas_w, 
    -height => $canvas_h, 
    -background => 'black'
)->pack();

# Create Live Score Display text on the canvas
my $score_text = $canvas->createText(
    520, 15, 
    -text => "SCORE: 0", 
    -fill => 'white', 
    -font => '{Arial} 12 bold'
);

# Create Paddle 
my $paddle = $canvas->createRectangle(
    260, 370, 260 + $paddle_w, 370 + $paddle_h, 
    -fill => 'cyan'
);

# Create Ball
my $ball = $canvas->createOval(
    $ball_x - $ball_r, $ball_y - $ball_r, 
    $ball_x + $ball_r, $ball_y + $ball_r, 
    -fill => 'white'
);

# Generate Bricks 
my @bricks;
my $rows = 4;
my $cols = 8;
my $b_w  = 65;
my $b_h  = 20;
my $pad  = 8;
my @colors = ('red', 'orange', 'yellow', 'green');

for my $r (0 .. $rows - 1) {
    for my $c (0 .. $cols - 1) {
        my $x1 = $c * ($b_w + $pad) + 15;
        my $y1 = $r * ($b_h + $pad) + 35; # Shifted slightly down for the score
        my $brick = $canvas->createRectangle(
            $x1, $y1, $x1 + $b_w, $y1 + $b_h, 
            -fill => $colors[$r], -tags => 'brick'
        );
        push @bricks, $brick;
    }
}

# --- Game Logic & Event Handling ---

# Mouse motion updates paddle position
$canvas->CanvasBind('<Motion>', sub {
    my ($c) = @_;
    my $e = $c->XEvent;
    my $mx = $e->x;
    
    $mx = $paddle_w / 2 if $mx < $paddle_w / 2;
    $mx = $canvas_w - ($paddle_w / 2) if $mx > $canvas_w - ($paddle_w / 2);
    
    $canvas->coords($paddle, $mx - ($paddle_w/2), 370, $mx + ($paddle_w/2), 370 + $paddle_h);
});

# Core Game Loop
sub update_game {
    $ball_x += $dx;
    $ball_y += $dy;
    $canvas->coords($ball, $ball_x - $ball_r, $ball_y - $ball_r, $ball_x + $ball_r, $ball_y + $ball_r);

    # 1. Wall Collisions
    if ($ball_x - $ball_r <= 0 || $ball_x + $ball_r >= $canvas_w) { $dx = -$dx; }
    if ($ball_y - $ball_r <= 0) { $dy = -$dy; }

    # 2. Paddle Collision
    my (@paddle_coords) = $canvas->coords($paddle);
    if ($ball_y + $ball_r >= $paddle_coords[1] && 
        $ball_x >= $paddle_coords[0] && 
        $ball_x <= $paddle_coords[2] && 
        $dy > 0) {
        $dy = -$dy;
    }

    # 3. Brick Collisions & Score Update
    my @overlapping = $canvas->find('overlapping', $ball_x - $ball_r, $ball_y - $ball_r, $ball_x + $ball_r, $ball_y + $ball_r);
    for my $item (@overlapping) {
        if (grep { $_ == $item } @bricks) {
            $canvas->delete($item);                           
            @bricks = grep { $_ != $item } @bricks;           
            $dy = -$dy;                                       
            
            # --- Incremental Score Update ---
            $score += $points_per_brick;
            $canvas->itemconfigure($score_text, -text => "SCORE: $score");
            
            last;
        }
    }

    # 4. Defeat Condition
    if ($ball_y + $ball_r >= $canvas_h) {
        $canvas->createText(300, 200, -text => "GAME OVER\nFinal Score: $score", -fill => 'red', -font => '{Arial} 24 bold', -justify => 'center');
        return; 
    }

    # Win Condition
    if (!@bricks) {
        $canvas->createText(300, 200, -text => "YOU WIN!\nFinal Score: $score", -fill => 'green', -font => '{Arial} 24 bold', -justify => 'center');
        return;
    }

    $mw->after(16, \&update_game);
}

$mw->after(500, \&update_game);
MainLoop;

