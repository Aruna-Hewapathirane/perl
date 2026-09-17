use strict;
use warnings;
use Gtk3 '-init';
use Cairo;

# --- Game Configuration ---
my $WIDTH  = 600;
my $HEIGHT = 400;

my $PADDLE_WIDTH  = 10;
my $PADDLE_HEIGHT = 80;
my $BALL_SIZE     = 12;

# --- Game State ---
my $ball_x  = $WIDTH / 2;
my $ball_y  = $HEIGHT / 2;
my $ball_dx = 4;
my $ball_dy = 3;

my $player_y = ($HEIGHT - $PADDLE_HEIGHT) / 2;
my $ai_y     = ($HEIGHT - $PADDLE_HEIGHT) / 2;

my $player_score = 0;
my $ai_score     = 0;
my $game_over    = 0;
my $game_started = 0; # Tracks if the current round is active

# --- Difficulty Settings ---
my $current_difficulty = 'Medium';
my $ai_max_speed = 2.8; 

my %ball_colors = (
    'Easy'       => [0.2, 0.9, 0.2], 
    'Medium'     => [1.0, 0.8, 0.2], 
    'Impossible' => [1.0, 0.2, 0.2], 
);

# --- Window & Layout Setup ---
my $window = Gtk3::Window->new('toplevel');
$window->set_title('Perl + GTK3 Pong');
$window->set_resizable(0);
$window->signal_connect(destroy => sub { Gtk3::main_quit });

# Bind keyboard press to detect Spacebar
$window->signal_connect('key-press-event' => \&on_key_press);

# Main vertical container
my $main_box = Gtk3::Box->new('vertical', 5);
$window->add($main_box);

# Toolbar layout
my $toolbar = Gtk3::Box->new('horizontal', 10);
$toolbar->set_border_width(5);
$main_box->pack_start($toolbar, 0, 0, 0);

my $menu_label = Gtk3::Label->new("Select Difficulty:");
$toolbar->pack_start($menu_label, 0, 0, 0);

my $combo = Gtk3::ComboBoxText->new();
$combo->append_text('Easy');
$combo->append_text('Medium');
$combo->append_text('Impossible');
$combo->set_active(1); 
$combo->signal_connect(changed => \&on_difficulty_changed);
$toolbar->pack_start($combo, 0, 0, 0);

# Game Canvas
my $canvas = Gtk3::DrawingArea->new();
$canvas->set_size_request($WIDTH, $HEIGHT);
$main_box->pack_start($canvas, 1, 1, 0);

$canvas->add_events(['pointer-motion-mask']);
$canvas->signal_connect(draw           => \&on_draw);
$canvas->signal_connect('motion-notify-event' => \&on_mouse_move);

# --- Game Loops & Logic ---

Glib::Timeout->add(16, sub {
    update_game();
    $canvas->queue_draw(); 
    return 1;              
});

sub update_game {
    return if $game_over;
    return if !$game_started; 

    # 1. Move the ball
    $ball_x += $ball_dx;
    $ball_y += $ball_dy;

    # 2. Top and Bottom Wall Collisions
    if ($ball_y <= 0 || $ball_y >= $HEIGHT - $BALL_SIZE) {
        $ball_dy = -$ball_dy;
    }

    # 3. Dynamic AI Paddle Movement
    my $ai_center = $ai_y + ($PADDLE_HEIGHT / 2);
    if ($current_difficulty eq 'Impossible') {
        if ($ai_center < $ball_y && $ai_y < $HEIGHT - $PADDLE_HEIGHT) {
            $ai_y += 3;
        } elsif ($ai_center > $ball_y && $ai_y > 0) {
            $ai_y -= 3;
        }
    } else {
        if ($ball_x > $WIDTH / 3) {
            if ($ai_center < $ball_y && $ai_y < $HEIGHT - $PADDLE_HEIGHT) {
                $ai_y += $ai_max_speed;
            } elsif ($ai_center > $ball_y && $ai_y > 0) {
                $ai_y -= $ai_max_speed;
            }
        }
    }

    # 4. Collision: Left Paddle (Player)
    if ($ball_dx < 0) {
        if ($ball_x <= $PADDLE_WIDTH && $ball_x >= 0) {
            if ($ball_y + $BALL_SIZE >= $player_y && $ball_y <= $player_y + $PADDLE_HEIGHT) {
                $ball_dx = -$ball_dx;
                $ball_dx *= 1.05; 
            }
        }
    }

    # 5. Collision: Right Paddle (AI)
    if ($ball_dx > 0) {
        if ($ball_x + $BALL_SIZE >= $WIDTH - $PADDLE_WIDTH && $ball_x <= $WIDTH) {
            if ($ball_y + $BALL_SIZE >= $ai_y && $ball_y <= $ai_y + $PADDLE_HEIGHT) {
                $ball_dx = -$ball_dx;
            }
        }
    }

    # 6. Scoring System & Win Condition Check
    if ($ball_x < 0) {
        $ai_score++;
        if ($ai_score >= 5) {
            $game_over = 1;
        } else {
            reset_ball();
        }
    } elsif ($ball_x > $WIDTH) {
        $player_score++;
        if ($player_score >= 5) {
            $game_over = 1;
        } else {
            reset_ball();
        }
    }
}

sub reset_ball {
    $ball_x  = $WIDTH / 2;
    $ball_y  = $HEIGHT / 2;
    $ball_dx = ($ball_dx > 0) ? -4 : 4; 
    $ball_dy = (rand(2) > 1) ? 3 : -3;
    $game_started = 0; 
}

# --- Event Handlers ---

# Handle Keypress Events via native Gtk3 namespaces
sub on_key_press {
    my ($widget, $event) = @_;
    
    # FIXED: Access keyval_name using the correct internal Gtk3 layout namespace
    my $keyname = Gtk3::Gdk::keyval_name($event->keyval);

    if ($keyname eq 'space' && !$game_over) {
        $game_started = 1;
    }
    return 1;
}

sub on_difficulty_changed {
    my ($widget) = @_;
    my $text = $widget->get_active_text();
    $current_difficulty = $text;

    if ($text eq 'Easy') {
        $ai_max_speed = 2.0;
    } elsif ($text eq 'Medium') {
        $ai_max_speed = 2.8;
    }
    
    $player_score = 0;
    $ai_score = 0;
    $game_over = 0;
    reset_ball();
}

sub on_mouse_move {
    return if $game_over; 
    
    my ($widget, $event) = @_;
    my $mouse_y = $event->y;
    
    $player_y = $mouse_y - ($PADDLE_HEIGHT / 2);
    if ($player_y < 0) { $player_y = 0; }
    if ($player_y > $HEIGHT - $PADDLE_HEIGHT) { $player_y = $HEIGHT - $PADDLE_HEIGHT; }
    
    return 1;
}

sub on_draw {
    my ($widget, $cr) = @_;

    # Draw Background (Black)
    $cr->set_source_rgb(0, 0, 0);
    $cr->paint();

    # Draw Center Net Line (Dotted)
    $cr->set_source_rgb(0.5, 0.5, 0.5);
    $cr->set_line_width(2);
    $cr->set_dash(0, 10, 10); 
    $cr->move_to($WIDTH / 2, 0);
    $cr->line_to($WIDTH / 2, $HEIGHT);
    $cr->stroke();
    $cr->set_dash(0); 

    # Draw Player Paddle (White, Left Side)
    $cr->set_source_rgb(1, 1, 1);
    $cr->rectangle(0, $player_y, $PADDLE_WIDTH, $PADDLE_HEIGHT);
    $cr->fill();

    # Draw AI Paddle (White, Right Side)
    $cr->rectangle($WIDTH - $PADDLE_WIDTH, $ai_y, $PADDLE_WIDTH, $PADDLE_HEIGHT);
    $cr->fill();

    # --- Centered Text Rendering ---
    $cr->select_font_face("Monospace", 'normal', 'bold');
    
    # Draw Scores
    $cr->set_font_size(30);
    $cr->set_source_rgb(0.5, 0.5, 0.5);
    
    my $p_ext = $cr->text_extents($player_score);
    $cr->move_to(($WIDTH / 4) - ($p_ext->{width} / 2), 40);
    $cr->show_text($player_score);
    
    my $ai_ext = $cr->text_extents($ai_score);
    $cr->move_to((3 * $WIDTH / 4) - ($ai_ext->{width} / 2), 40);
    $cr->show_text($ai_score);

    # Render Screen Overlays (Game Over vs Waiting to Start vs Active Play)
    if ($game_over) {
        $cr->set_source_rgba(0, 0, 0, 0.75);
        $cr->rectangle(0, 0, $WIDTH, $HEIGHT);
        $cr->fill();

        $cr->set_source_rgb(1, 1, 1);
        $cr->set_font_size(40);
        my $go_ext = $cr->text_extents("GAME OVER");
        $cr->move_to(($WIDTH / 2) - ($go_ext->{width} / 2), ($HEIGHT / 2) - 20);
        $cr->show_text("GAME OVER");

        $cr->set_font_size(20);
        my $win_text = ($player_score >= 5) ? "You Defeated the AI!" : "The Computer Wins!";
        my $w_ext = $cr->text_extents($win_text);
        if ($player_score >= 5) { $cr->set_source_rgb(0.2, 0.9, 0.2); } 
        else { $cr->set_source_rgb(1.0, 0.2, 0.2); }
        $cr->move_to(($WIDTH / 2) - ($w_ext->{width} / 2), ($HEIGHT / 2) + 20);
        $cr->show_text($win_text);

        $cr->set_source_rgb(0.6, 0.6, 0.6);
        $cr->set_font_size(14);
        my $sub_text = "Change difficulty to play again";
        my $s_ext = $cr->text_extents($sub_text);
        $cr->move_to(($WIDTH / 2) - ($s_ext->{width} / 2), ($HEIGHT / 2) + 60);
        $cr->show_text($sub_text);

    } elsif (!$game_started) {
        $cr->set_source_rgba(0, 0, 0, 0.5);
        $cr->rectangle(0, 0, $WIDTH, $HEIGHT);
        $cr->fill();

        $cr->set_source_rgb(1, 1, 1);
        $cr->set_font_size(24);
        my $start_text = "PRESS SPACEBAR TO SERVE";
        my $st_ext = $cr->text_extents($start_text);
        $cr->move_to(($WIDTH / 2) - ($st_ext->{width} / 2), ($HEIGHT / 2));
        $cr->show_text($start_text);

        # Render the stagnant colored ball
        my $color = $ball_colors{$current_difficulty} || [1.0, 0.8, 0.2];
        $cr->set_source_rgb(@$color);
        $cr->rectangle($ball_x, $ball_y, $BALL_SIZE, $BALL_SIZE);
        $cr->fill();
    } else {
        # Draw moving ball normally
        my $color = $ball_colors{$current_difficulty} || [1.0, 0.8, 0.2];
        $cr->set_source_rgb(@$color);
        $cr->rectangle($ball_x, $ball_y, $BALL_SIZE, $BALL_SIZE);
        $cr->fill();
    }

    return 1;
}

$window->show_all;
Gtk3::main;

