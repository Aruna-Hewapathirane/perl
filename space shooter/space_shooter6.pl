#!/usr/bin/env perl
use strict;
use warnings;
use Gtk3 '-init';
use Glib qw(TRUE FALSE);
use Cairo;

# --- Game Configuration ---
my $WINDOW_WIDTH  = 500; 
my $WINDOW_HEIGHT = 600;
my $FRAME_RATE    = 30; 

# --- Game State ---
my $game_started = 0; 
my $player = {
    x      => 230,     
    y      => 500,
    width  => 50,
    height => 50,
    speed  => 7,
};

my @lasers       = ();
my @enemies      = ();
my @stars        = ();
my @particles    = (); 
my %keys         = ();
my $score        = 0;
my $current_lvl  = 1;
my $game_over    = 0;
my $spawn_timer  = 0;

my $boss = {
    active => 0,
    x      => 200,
    y      => -100,
    width  => 100,
    height => 80,
    hp     => 50,
    max_hp => 50,
    speed  => 3,
    dir    => 1,
};

my %level_colors = (
    1 => [1.0, 1.0, 1.0],
    2 => [0.2, 1.0, 0.2],
    3 => [1.0, 1.0, 0.0],
    4 => [1.0, 0.3, 1.0],
    5 => [1.0, 0.2, 0.2],
);

for (1..40) {
    push @stars, {
        x     => int(rand($WINDOW_WIDTH)),
        y     => int(rand($WINDOW_HEIGHT)),
        speed => 1 + rand(3),
        size  => 1 + int(rand(2)),
    };
}

my $player_pixbuf = Gtk3::Gdk::Pixbuf->new_from_file_at_scale("player.png", $player->{width}, $player->{height}, FALSE);
my $enemy_pixbuf  = Gtk3::Gdk::Pixbuf->new_from_file_at_scale("enemy.png", 40, 40, FALSE);
my $laser_pixbuf  = Gtk3::Gdk::Pixbuf->new_from_file_at_scale("laser.png", 4, 15, FALSE);
my $boss_pixbuf   = Gtk3::Gdk::Pixbuf->new_from_file_at_scale("enemy.png", $boss->{width}, $boss->{height}, FALSE);

sub play_sound {
    my ($file) = @_;
    my $pid = fork();
    if (defined $pid && $pid == 0) {
        open(STDOUT, '>', '/dev/null');
        open(STDERR, '>', '/dev/null');
        exec("aplay", "-q", $file);
        exit(0);
    }
}

sub spawn_explosion {
    my ($x, $y, $color, $count) = @_;
    $count //= 15;
    for (1..$count) {
        push @particles, {
            x     => $x,
            y     => $y,
            vx    => (rand(6) - 3),    
            vy    => (rand(6) - 3),    
            life  => 15 + int(rand(10)), 
            color => $color // [1.0, 0.5, 0.0], 
        };
    }
}

my $window = Gtk3::Window->new('toplevel');
$window->set_title("Camel Combat: Gtk3 Onslaught");
$window->set_default_size($WINDOW_WIDTH, $WINDOW_HEIGHT);
$window->set_resizable(FALSE);

my $area = Gtk3::DrawingArea->new();
$window->add($area);

$window->signal_connect(destroy => sub { Gtk3::main_quit(); });
$window->signal_connect('key-press-event'   => \&on_key_press);
$window->signal_connect('key-release-event' => \&on_key_release);
$area->signal_connect('draw'                => \&on_draw);

Glib::Timeout->add($FRAME_RATE, \&game_loop);
$window->show_all();
Gtk3::main();

sub on_key_press {
    my ($widget, $event) = @_;
    my $key_name = Gtk3::Gdk::keyval_name($event->keyval);
    
    if (!$game_started) {
        $game_started = 1;
        play_sound("fire.wav");
        return TRUE;
    }

    $keys{$key_name} = 1;
    if ($game_over && $key_name eq 'r') { reset_game(); }
    return TRUE;
}

sub on_key_release {
    my ($widget, $event) = @_;
    my $key_name = Gtk3::Gdk::keyval_name($event->keyval);
    $keys{$key_name} = 0;
    return TRUE;
}

sub reset_game {
    $player->{x} = 230;
    $player->{y} = 500;
    @lasers = ();
    @enemies = ();
    @particles = ();
    $score = 0;
    $current_lvl = 1;
    $game_over = 0;
    $boss->{active} = 0;
    $boss->{y} = -100;
    $boss->{hp} = $boss->{max_hp};
}

sub check_collision {
    my ($r1, $r2) = @_;
    return !(
        $r1->{x} > $r2->{x} + $r2->{width}  ||
        $r1->{x} + $r1->{width} < $r2->{x}  ||
        $r1->{y} > $r2->{y} + $r2->{height} ||
        $r1->{y} + $r1->{height} < $r2->{y}
    );
}

sub game_loop {
    foreach my $star (@stars) {
        $star->{y} += $star->{speed};
        if ($star->{y} > $WINDOW_HEIGHT) {
            $star->{y} = 0;
            $star->{x} = int(rand($WINDOW_WIDTH));
        }
    }

    foreach my $p (@particles) {
        $p->{x} += $p->{vx};
        $p->{y} += $p->{vy};
        $p->{life}--;
    }
    @particles = grep { $_->{life} > 0 } @particles;

    if (!$game_started) {
        $spawn_timer++; 
        $area->queue_draw();
        return TRUE;
    }

    return TRUE if $game_over;

    if    ($score < 100) { $current_lvl = 1; }
    elsif ($score < 200) { $current_lvl = 2; }
    elsif ($score < 300) { $current_lvl = 3; }
    elsif ($score < 400) { $current_lvl = 4; }
    else { 
        $current_lvl = 5; 
        $boss->{active} = 1 if $boss->{hp} > 0;
    }

    if ($keys{Left}  && $player->{x} > 0) { $player->{x} -= $player->{speed}; }
    if ($keys{Right} && $player->{x} < $WINDOW_WIDTH - $player->{width}) { $player->{x} += $player->{speed}; }
    
    if ($keys{space}) {
        if ($spawn_timer % 6 == 0) { 
            push @lasers, {
                x      => $player->{x} + ($player->{width} / 2) - 2,
                y      => $player->{y},
                width  => 4,
                height => 15,
                speed  => 12,
            };
            play_sound("fire.wav");
        }
    }

    $spawn_timer++;

    my $spawn_rate = 45 - ($current_lvl * 6); 
    if ($spawn_timer % $spawn_rate == 0) {
        push @enemies, {
            x      => int(rand($WINDOW_WIDTH - 30)),
            y      => -30,
            width  => 40,
            height => 40,
            speed  => 2 + $current_lvl + int(rand(3)),
        };
    }

    if ($boss->{active}) {
        if ($boss->{y} < 60) { $boss->{y} += 2; } 
        else {
            $boss->{x} += $boss->{speed} * $boss->{dir};
            if ($boss->{x} <= 10 || $boss->{x} >= $WINDOW_WIDTH - $boss->{width} - 10) {
                $boss->{dir} *= -1;
            }
        }
    }

    foreach my $laser (@lasers) { $laser->{y} -= $laser->{speed}; }
    @lasers = grep { $_->{y} > -20 } @lasers;

    foreach my $enemy (@enemies) { $enemy->{y} += $enemy->{speed}; }
    @enemies = grep { $_->{y} < $WINDOW_HEIGHT } @enemies;

    my $current_color = $level_colors{$current_lvl} // [1.0, 1.0, 1.0];
    foreach my $laser (@lasers) {
        foreach my $enemy (@enemies) {
            next if $enemy->{hit};
            if (check_collision($laser, $enemy)) {
                $enemy->{hit} = 1;
                $laser->{hit} = 1;
                $score += 10;
                spawn_explosion($enemy->{x} + 15, $enemy->{y} + 15, $current_color, 12);
                play_sound("explosion.wav");
            }
        }
        
        if ($boss->{active} && !$laser->{hit}) {
            if (check_collision($laser, $boss)) {
                $laser->{hit} = 1;
                $boss->{hp}--;
                spawn_explosion($laser->{x}, $laser->{y}, [1.0, 1.0, 0.3], 5);
                if ($boss->{hp} <= 0) {
                    $boss->{active} = 0;
                    $score += 1000;
                    spawn_explosion($boss->{x} + 50, $boss->{y} + 40, [1.0, 0.2, 0.2], 50);
                    play_sound("explosion.wav");
                }
            }
        }
    }
    @enemies = grep { !$_->{hit} } @enemies;
    @lasers  = grep { !$_->{hit} } @lasers;

    foreach my $enemy (@enemies) {
        if (check_collision($player, $enemy)) { 
            $game_over = 1; 
            spawn_explosion($player->{x} + 20, $player->{y} + 15, [0.0, 0.8, 1.0], 35);
            play_sound("explosion.wav");
        }
    }
    if ($boss->{active} && check_collision($player, $boss)) {
        $game_over = 1;
        spawn_explosion($player->{x} + 20, $player->{y} + 15, [0.0, 0.8, 1.0], 35);
        play_sound("explosion.wav");
    }

    $area->queue_draw();
    return TRUE;
}

sub on_draw {
    my ($widget, $cr) = @_;

    $cr->set_source_rgb(0, 0, 0.05); 
    $cr->paint();

    $cr->set_source_rgb(0.8, 0.8, 0.9); 
    foreach my $star (@stars) {
        $cr->rectangle($star->{x}, $star->{y}, $star->{size}, $star->{size});
        $cr->fill();
    }

    $cr->set_operator('over');

    foreach my $p (@particles) {
        $cr->set_source_rgb($p->{color}->[0], $p->{color}->[1], $p->{color}->[2]);
        $cr->rectangle($p->{x}, $p->{y}, 3, 3);
        $cr->fill();
    }

if (!$game_started) {
        # --- 🌟 CUSTOM SPLASH SCREEN LAYOUT 🌟 ---
        
        # 1. Main Game Title: "Add Your Game Title here"
        $cr->set_source_rgb(0.9, 0.7, 0.1); # Gold
        $cr->select_font_face("Sans", 'normal', 'bold');
        $cr->set_font_size(38);
        my $t1 = "CYBERNETICS";
        my $ext_t1 = $cr->text_extents($t1);
        my $t1x = ($WINDOW_WIDTH  / 2) - ($ext_t1->{width}  / 2) - $ext_t1->{x_bearing};
        my $t1y = ($WINDOW_HEIGHT / 2) - 80;
        $cr->move_to($t1x, $t1y);
        $cr->show_text($t1);

        # 2. Credits Line 1: "Created By"
        $cr->set_source_rgb(1.0, 1.0, 1.0); # White
        $cr->select_font_face("Sans", 'normal', 'normal');
        $cr->set_font_size(14);
        my $t2 = "By Aruna And";
        my $ext_t2 = $cr->text_extents($t2);
        my $t2x = ($WINDOW_WIDTH  / 2) - ($ext_t2->{width}  / 2) - $ext_t2->{x_bearing};
        my $t2y = $t1y + 40;
        $cr->move_to($t2x, $t2y);
        $cr->show_text($t2);

        # 3. Credits Line 2: "Aruna & Pathologically eclectant rubbish listing"
        $cr->set_source_rgb(1, 1, 1); # white
        $cr->select_font_face("Sans", 'normal', 'normal');
        $cr->set_font_size(14);
        my $t3 = "Pathologically Eclectant Rubbish Listing";
        my $ext_t3 = $cr->text_extents($t3);
        my $t3x = ($WINDOW_WIDTH  / 2) - ($ext_t3->{width}  / 2) - $ext_t3->{x_bearing};
        my $t3y = $t2y + 25;
        $cr->move_to($t3x, $t3y);
        $cr->show_text($t3);

	if (($spawn_timer / 15) % 2 == 0) {
            $cr->set_source_rgb(1, 1, 1); 
            $cr->select_font_face("Sans", 'normal', 'normal');
            $cr->set_font_size(16);
            
            my $prompt = "PRESS ANY KEY TO START";
            my $ext_p = $cr->text_extents($prompt);
            my $px = ($WINDOW_WIDTH / 2) - ($ext_p->{width} / 2) - $ext_p->{x_bearing};
            my $py = $t2y + 280;
            
            $cr->move_to($px, $py);
            $cr->show_text($prompt);
        }
        return FALSE;
    }

    if ($game_over) {
        $cr->set_source_rgb(1, 0, 0); 
        $cr->select_font_face("Sans", 'normal', 'bold');
        $cr->set_font_size(40);
        
        my $main_text = "GAME OVER";
        my $ext1 = $cr->text_extents($main_text);
        my $x1 = ($WINDOW_WIDTH  / 2) - ($ext1->{width}  / 2) - $ext1->{x_bearing};
        my $y1 = ($WINDOW_HEIGHT / 2) - ($ext1->{height} / 2) - $ext1->{y_bearing};
        
$cr->move_to($x1, $y1);
$cr->show_text($main_text);

$cr->set_source_rgb(1, 1, 1);
$cr->select_font_face("Sans", 'normal', 'normal');
$cr->set_font_size(16);

my $sub_text = "Press 'R' to Restart";
my $ext2 = $cr->text_extents($sub_text);
my $x2 = ($WINDOW_WIDTH / 2) - ($ext2->{width} / 2) - $ext2->{x_bearing};
my $y2 = $y1 + 40;

$cr->move_to($x2, $y2);
$cr->show_text($sub_text);
} elsif ($boss->{hp} <= 0 && $current_lvl == 5) {
	$cr->set_source_rgb(0, 1, 0);
	$cr->select_font_face("Sans", 'normal', 'bold');
	$cr->set_font_size(30);
	
	my $vic_text = "VICTORY ACHIEVED!";
	my $ext_v = $cr->text_extents($vic_text);
	my $vx = ($WINDOW_WIDTH / 2) - ($ext_v->{width} / 2) - $ext_v->{x_bearing};
	my $vy = ($WINDOW_HEIGHT / 2) - ($ext_v->{height} / 2) - $ext_v->{y_bearing};
	
	$cr->move_to($vx, $vy);
	$cr->show_text($vic_text);
	$cr->set_source_rgb(1, 1, 1);
	$cr->set_font_size(16);
	$cr->move_to($vx + 20, $vy + 40);
	$cr->show_text("Press 'R' to Play Again");
} else {$cr->save();
	Gtk3::Gdk::cairo_set_source_pixbuf($cr, $player_pixbuf, $player->{x}, $player->{y});
	$cr->paint();
	$cr->restore();
	
	foreach my $laser (@lasers) {
		$cr->save();
		Gtk3::Gdk::cairo_set_source_pixbuf($cr, $laser_pixbuf, $laser->{x}, $laser->{y});
		$cr->paint();
		$cr->restore();
	}
		my $color = $level_colors{$current_lvl} // [1.0, 1.0, 1.0];
		
		foreach my $enemy (@enemies) {
			$cr->save();
			$cr->rectangle($enemy->{x}, $enemy->{y}, $enemy->{width}, $enemy->{height});
			$cr->clip();
			
			Gtk3::Gdk::cairo_set_source_pixbuf($cr, $enemy_pixbuf, $enemy->{x}, $enemy->{y});
			$cr->paint();
			
			$cr->set_source_rgb($color->[0], $color->[1], $color->[2]);
			$cr->set_operator('multiply');
			$cr->paint();
			$cr->restore();
		}
		
		$cr->set_operator('over');
		
		if ($boss->{active}) {
			$cr->save();
			Gtk3::Gdk::cairo_set_source_pixbuf($cr, $boss_pixbuf, $boss->{x}, $boss->{y});
			$cr->paint();
			$cr->restore();
			
			$cr->set_source_rgb(0.3, 0, 0);
			$cr->rectangle($boss->{x}, $boss->{y} - 15, $boss->{width}, 6);
			$cr->fill();
			
			my $hp_pct = $boss->{hp} / $boss->{max_hp};
			$cr->set_source_rgb(1, 0, 0);
			$cr->rectangle($boss->{x}, $boss->{y} - 15, $boss->{width} * $hp_pct, 6);
			$cr->fill();
		}
	}
	
	$cr->set_operator('over');
	$cr->set_source_rgb(1, 1, 1);
	$cr->select_font_face("Sans", 'normal', 'normal');
	$cr->set_font_size(14);
	$cr->move_to(10, 25);
	
	my $lvl_display = ($current_lvl == 5) ? "FINAL BOSS" : "LEVEL $current_lvl";
	$cr->show_text("Score: $score   |   $lvl_display");
	return FALSE;
}
