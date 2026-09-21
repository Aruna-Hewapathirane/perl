#!/usr/bin/env perl
use strict;
use warnings;
use Gtk3 '-init';
use Cairo;

# --- Game Configuration ---
my $WINDOW_WIDTH  = 600;
my $WINDOW_HEIGHT = 550; 
my $SCALE         = 4; 

my $GRID_W = int($WINDOW_WIDTH / $SCALE);
my $GRID_H = int(($WINDOW_HEIGHT - 50) / $SCALE); 

# --- Global Game Systems State ---
my $score        = 0;
my $lives        = 3;
my $level        = 1;
my $pct_captured = 0;
my $game_over    = 0;
my $in_splash    = 1; # Game starts in splash screen mode

# --- Playfield Grid State ---
my @grid;
my $total_playable_cells = 0; 

sub init_grid {
    $total_playable_cells = 0;
    for my $x (0 .. $GRID_W - 1) {
        for my $y (0 .. $GRID_H - 1) {
            if ($x <= 5 || $x >= $GRID_W - 6 || $y <= 5 || $y >= $GRID_H - 6) {
                $grid[$x][$y] = 1; 
            } else {
                $grid[$x][$y] = 0; 
                $total_playable_cells++;
            }
        }
    }
    $pct_captured = 0;
}

# --- Player State ---
my ($px, $py)     = (int($GRID_W / 2), $GRID_H - 6);
my ($p_dx, $p_dy) = (0, 0);
my $is_drawing    = 0;
my $draw_mode     = 'fast'; 
my $move_tick     = 0;      

# --- Fuse & Spark State Engine ---
my @trail_history = (); 
my $still_timer   = 0;  
my $spark_active  = 0;  
my ($spark_x, $spark_y);
my $spark_move_tick = 0;

# --- Multi-Stix Enemy Systems Engine ---
my @stix_enemies = ();

sub init_stix_for_level {
    @stix_enemies = ();
    my $stix_count = $level;
    $stix_count = 3 if $stix_count > 3;

    for (1 .. $stix_count) {
        push @stix_enemies, {
            x       => int($GRID_W / 2) + ($_ * 4 - 4),
            y       => int($GRID_H / 2),
            dx      => 0.6 + (rand(0.3)),
            dy      => 0.4 + (rand(0.3)),
            history => [],
        };
    }
}

# Initial Setup
init_grid();
init_stix_for_level();

# --- GTK Engine Setup ---
my $window = Gtk3::Window->new('toplevel');
$window->set_title('C64 STIX 1983 - RESURRECTED BY ARUNA 2026');
$window->set_default_size($WINDOW_WIDTH, $WINDOW_HEIGHT);
$window->signal_connect(destroy => sub { Gtk3::main_quit(); });

my $canvas = Gtk3::DrawingArea->new();
$window->add($canvas);

$canvas->signal_connect(draw => \&draw_callback);
$window->signal_connect('key-press-event'   => \&on_key_press);
$window->signal_connect('key-release-event' => \&on_key_release);

Glib::Timeout->add(16, \&game_loop);

$window->show_all();
Gtk3::main();

# --- Game Engine Loops & Logic ---
sub game_loop {
    return 1 if $in_splash; # Halt logic updates during splash screen
    return 1 if $game_over;
    $move_tick++;

    # 1. Update All Active Stix Positions & Trail Histories
    for my $stix (@stix_enemies) {
        $stix->{x} += $stix->{dx}; 
        $stix->{y} += $stix->{dy};

        my $next_sx = int($stix->{x} + $stix->{dx});
        my $next_sy = int($stix->{y} + $stix->{dy});
        if ($next_sx < 0 || $next_sx >= $GRID_W || $grid[$next_sx][int($stix->{y})] == 1) { $stix->{dx} *= -1; }
        if ($next_sy < 0 || $next_sy >= $GRID_H || $grid[int($stix->{x})][$next_sy] == 1) { $stix->{dy} *= -1; }

        push @{$stix->{history}}, [ $stix->{x} * $SCALE, $stix->{y} * $SCALE ];
        shift @{$stix->{history}} if @{$stix->{history}} > 12;
    }

    # 2. Player Input / Movement Vector Engine
    my $is_moving = ($p_dx != 0 || $p_dy != 0) ? 1 : 0;
    my $should_move = 1;
    if ($is_drawing && $draw_mode eq 'slow') {
        $should_move = ($move_tick % 2 == 0) ? 1 : 0;
    }

    if ($should_move && $is_moving) {
        my $nx = $px + $p_dx;
        my $ny = $py + $p_dy;

        if ($nx >= 0 && $nx < $GRID_W && $ny >= 0 && $ny < $GRID_H) {
            my $target_cell = $grid[$nx][$ny];

            if ($target_cell == 0) {
                $is_drawing = 1;
                $grid[$nx][$ny] = ($draw_mode eq 'fast') ? 2 : 3;
                $px = $nx; $py = $ny;
                
                push @trail_history, [ $px, $py ];
            }
            elsif ($target_cell == 1) {
                if ($is_drawing) {
                    $px = $nx; $py = $ny;
                    trigger_flood_fill();
                    reset_spark_engine();
                } else {
                    $px = $nx; $py = $ny;
                }
            }
            elsif ($target_cell == 2 || $target_cell == 3) {
                handle_player_death(); 
            }
        }
    }

    # 3. Fuse Spark Tracking AI
    if ($is_drawing) {
        if (!$is_moving && !$spark_active) {
            $still_timer++;
            if ($still_timer >= 60) { 
                $spark_active = 1;
                if (@trail_history) {
                    $spark_x = $trail_history[0]->[0];
                    $spark_y = $trail_history[0]->[1];
                } else {
                    ($spark_x, $spark_y) = ($px, $py);
                }
                $spark_move_tick = 0;
            }
        }

        if ($spark_active) {
            $spark_move_tick++;
            if ($spark_move_tick % 3 == 0) { 
                if (@trail_history > 1) {
                    my $next_step = shift @trail_history;
                    $spark_x = $next_step->[0];
                    $spark_y = $next_step->[1];
                } else {
                    ($spark_x, $spark_y) = ($px, $py);
                }
            }
            if ($spark_x == $px && $spark_y == $py) {
                handle_player_death();
            }
        }
    } else {
        reset_spark_engine();
    }

    # 4. Collision Engines
    if ($is_drawing) {
        for my $stix (@stix_enemies) {
            my $sc = $grid[int($stix->{x})][int($stix->{y})];
            if (defined $sc && ($sc == 2 || $sc == 3)) {
                handle_player_death();
                last;
            }
        }
    }

    $canvas->queue_draw();
    return 1;
}

sub reset_spark_engine {
    $still_timer   = 0;
    $spark_active  = 0;
    @trail_history = ();
}

# --- Flood Fill & Metrics Tracking Engine ---
sub trigger_flood_fill {
    my $has_slow_points = 0;
    for my $x (0 .. $GRID_W - 1) {
        for my $y (0 .. $GRID_H - 1) {
            if ($grid[$x][$y] == 2 || $grid[$x][$y] == 3) {
                $has_slow_points = 1 if $grid[$x][$y] == 3;
                $grid[$x][$y] = 1; 
            }
        }
    }

    my %visited;
    for my $stix (@stix_enemies) {
        my @queue = ( [ int($stix->{x}), int($stix->{y}) ] );
        $visited{int($stix->{x}) . "," . int($stix->{y})} = 1;

        my @dxs = (0,  0, -1, 1);
        my @dys = (-1, 1,  0, 0);

        while (@queue) {
            my $curr = shift @queue;
            my $cx = $curr->[0]; 
            my $cy = $curr->[1];

            for my $i (0 .. 3) {
                my $nx = $cx + $dxs[$i]; my $ny = $cy + $dys[$i];

                if ($nx >= 0 && $nx < $GRID_W && $ny >= 0 && $ny < $GRID_H) {
                    my $key = "$nx,$ny";
                    if ($grid[$nx][$ny] == 0 && !$visited{$key}) {
                        $visited{$key} = 1;
                        push @queue, [$nx, $ny];
                    }
                }
            }
        }
    }

    my $cells_captured = 0;
    my $remaining_unclaimed = 0;

    for my $x (0 .. $GRID_W - 1) {
        for my $y (0 .. $GRID_H - 1) {
            next if ($x <= 5 || $x >= $GRID_W - 6 || $y <= 5 || $y >= $GRID_H - 6);

            if ($grid[$x][$y] == 0) {
                if (!$visited{"$x,$y"}) {
                    $grid[$x][$y] = 1; 
                    $cells_captured++;
                } else {
                    $remaining_unclaimed++;
                }
            }
        }
    }

    my $multiplier = $has_slow_points ? 20 : 10;
    $score += $cells_captured * $multiplier * $level;

    my $claimed_total = $total_playable_cells - $remaining_unclaimed;
    $pct_captured = int(($claimed_total / $total_playable_cells) * 100);

    if ($pct_captured >= 75) {
        $level++;
        $score += 5000; 
        init_grid();
        init_stix_for_level();
        ($px, $py) = (int($GRID_W / 2), $GRID_H - 6);
    }
    $is_drawing = 0;
}

sub handle_player_death {
    $lives--;
    if ($lives <= 0) {
        $game_over = 1;
    } else {
        for my $x (0 .. $GRID_W - 1) {
            for my $y (0 .. $GRID_H - 1) {
                if ($grid[$x][$y] == 2 || $grid[$x][$y] == 3) {
                    $grid[$x][$y] = 0;
                }
            }
        }
        ($px, $py) = (int($GRID_W / 2), $GRID_H - 6);
        ($p_dx, $p_dy) = (0, 0);
        $is_drawing = 0;
        reset_spark_engine();
    }
}

# --- Cairo Drawing Systems ---
sub draw_callback {
    my ($widget, $cr) = @_;

    # Background
    $cr->set_source_rgb(0, 0, 0);
    $cr->paint();

    if ($in_splash) {
        # --- Render Splash Screen UI ---
        $cr->select_font_face("Monospace", 'normal', 'bold');
        
        # Retro Grid Effect Background Accent
        $cr->set_source_rgb(0.15, 0.1, 0.25);
        $cr->set_line_width(1);
        for (my $i = 0; $i < $WINDOW_WIDTH; $i += 40) {
            $cr->move_to($i, 0); $cr->line_to($i, $WINDOW_HEIGHT); $cr->stroke();
        }
        for (my $j = 0; $j < $WINDOW_HEIGHT; $j += 40) {
            $cr->move_to(0, $j); $cr->line_to($WINDOW_WIDTH, $j); $cr->stroke();
        }
# 1. Centered Title Line: STIX
    $cr->set_source_rgb(0, 1, 1);
    $cr->select_font_face("Monospace", 'normal', 'bold');
    $cr->set_font_size(68);
    my $ext_title = $cr->text_extents("STIX");
    my $title_x   = ($WINDOW_WIDTH / 2) - ($ext_title->{width} / 2) - $ext_title->{x_bearing};
    $cr->move_to($title_x, 150);
    $cr->show_text("STIX");
        
 # 2. Centered Author Line: STANRIFKIN
    $cr->set_source_rgb(1, 0.5, 0);
    $cr->set_font_size(14);
    my $ext_author = $cr->text_extents("STANRIFKIN VERSION");
    my $author_x   = ($WINDOW_WIDTH / 2) - ($ext_author->{width} / 2) - $ext_author->{x_bearing};
    $cr->move_to($author_x, 180);
    $cr->show_text("STANRIFKIN VERSION");    

  # 3. Centered Action Banner: PRESS A KEY TO PLAY
    $cr->set_source_rgb(1, 1, 0);
    $cr->set_font_size(14);
    my $ext_prompt = $cr->text_extents("PRESS A KEY TO PLAY");
    my $prompt_x   = ($WINDOW_WIDTH / 2) - ($ext_prompt->{width} / 2) - $ext_prompt->{x_bearing};
    $cr->move_to($prompt_x, 400);
    $cr->show_text("PRESS A KEY TO PLAY");   
}

    # Render Grid Board State
    for my $x (0 .. $GRID_W - 1) {
        for my $y (0 .. $GRID_H - 1) {
            my $cell = $grid[$x][$y];
            if ($cell == 1) { # Muted Arcade Navy Blue Walls
                $cr->set_source_rgb(0.1, 0.2, 0.5);
                $cr->rectangle($x * $SCALE, $y * $SCALE, $SCALE, $SCALE);
                $cr->fill();
            } elsif ($cell == 2) { # Fast Draw Trail (Orange)
                $cr->set_source_rgb(1, 0.5, 0);
                $cr->rectangle($x * $SCALE, $y * $SCALE, $SCALE, $SCALE);
                $cr->fill();
            } elsif ($cell == 3) { # Slow Draw Trail (Magenta)
                $cr->set_source_rgb(0.9, 0.1, 0.9);
                $cr->rectangle($x * $SCALE, $y * $SCALE, $SCALE, $SCALE);
                $cr->fill();
            }
        }
    }

    # Render Multi-Stix Lines
    for my $stix (@stix_enemies) {
        my $history = $stix->{history};
        if (@$history > 1) {
            for my $i (0 .. @$history - 2) {
                my $p1 = $history->[$i];
                my $p2 = $history->[$i+1];
                my $intensity = $i / @$history;
                $cr->set_source_rgb($intensity, 1 - $intensity, 0.5);
                $cr->set_line_width(2 + ($intensity * 2));
                $cr->move_to($p1->[0], $p1->[1]);
                $cr->line_to($p2->[0], $p2->[1]);
                $cr->stroke();
            }
        }
    }

    # Render Chasing Fuse Spark
    if ($is_drawing && $spark_active && !$game_over) {
        my $flicker = rand(1) > 0.5 ? 1 : 0;
        if ($flicker) { $cr->set_source_rgb(1, 1, 0); } else { $cr->set_source_rgb(1, 0, 0); }
        $cr->arc($spark_x * $SCALE, $spark_y * $SCALE, 5, 0, 2 * 3.14159);
        $cr->fill();
    }

    # Render Player Node
    if (!$game_over) {
        $cr->set_source_rgb(0, 1, 1);
        $cr->arc($px * $SCALE, $py * $SCALE, 5, 0, 2 * 3.14159); 
        $cr->fill();
    }

    # --- Draw Retro UI HUD Dashboard ---
    $cr->set_source_rgb(0.1, 0.1, 0.1);
    $cr->rectangle(0, $WINDOW_HEIGHT - 50, $WINDOW_WIDTH, 50); 
    $cr->fill();

    $cr->set_source_rgb(1, 1, 1);
    $cr->select_font_face("Monospace", 'normal', 'bold'); 
    $cr->set_font_size(14);

    if ($game_over) {
        $cr->set_source_rgb(1, 0, 0);
        $cr->move_to(($WINDOW_WIDTH / 2) - 80, $WINDOW_HEIGHT - 20);
        $cr->show_text("GAME OVER - PRESS R");
    } else {
        $cr->move_to(15, $WINDOW_HEIGHT - 20);
        $cr->show_text(sprintf("SCORE:%06d", $score));
        
        $cr->move_to(165, $WINDOW_HEIGHT - 20);
        $cr->show_text("LIVES:" . ("I" x $lives));
        
        $cr->move_to(275, $WINDOW_HEIGHT - 20);
        my $display_mode = uc($draw_mode);
        $cr->set_source_rgb(1, 0.5, 0) if $draw_mode eq 'fast';
        $cr->set_source_rgb(0.9, 0.1, 0.9) if $draw_mode eq 'slow';
        $cr->show_text("MODE:$display_mode");
        
        $cr->set_source_rgb(1, 1, 1);
        $cr->move_to(395, $WINDOW_HEIGHT - 20);
        $cr->show_text("STAGE:$level");
        
        $cr->set_source_rgb(0, 1, 0) if $pct_captured >= 65;
        $cr->move_to(485, $WINDOW_HEIGHT - 20);
        $cr->show_text("CAPTURED:$pct_captured%");
    }
    return 1;
}

# --- Keyboard Controller Hooks ---
sub on_key_press {
    my ($widget, $event) = @_;
    my $key = $event->keyval;

    # If in splash screen, any keypress starts the game
    if ($in_splash) {
        $in_splash = 0;
        $canvas->queue_draw();
        return 1;
    }

    if ($game_over && ($key == 112 || $key == 114)) { 
        $score = 0; $lives = 3; $level = 1; $game_over = 0;
        init_grid();
        init_stix_for_level();
        reset_spark_engine();
        ($px, $py) = (int($GRID_W / 2), $GRID_H - 6);
        return 1;
    }

    if ($key == 32 && !$is_drawing) { 
        $draw_mode = ($draw_mode eq 'fast') ? 'slow' : 'fast';
        return 1;
    }

    if    ($key == 65362) { $p_dy = -1; $p_dx = 0; } 
    elsif ($key == 65364) { $p_dy = 1;  $p_dx = 0; } 
    elsif ($key == 65361) { $p_dx = -1; $p_dy = 0; } 
    elsif ($key == 65363) { $p_dx = 1;  $p_dy = 0; } 

    return 1;
}

sub on_key_release {
    my ($widget, $event) = @_;
    my $key = $event->keyval;

    if (($key == 65362 && $p_dy == -1) || ($key == 65364 && $p_dy == 1))  { $p_dy = 0; }
    if (($key == 65361 && $p_dx == -1) || ($key == 65363 && $p_dx == 1))  { $p_dx = 0; }

    return 1;
}
