#!/usr/bin/env perl
#
# Nine Men's Morris - Perl + Gtk3
#
# Run:  perl morris.pl
# Needs: Gtk3, Cairo, Glib  (e.g. apt install libgtk3-perl libcairo-perl)
#
use strict;
use warnings;
use Gtk3 '-init';
use Glib qw(TRUE FALSE);
use List::Util qw(shuffle min);

use constant PI => 3.14159265358979;

# ---------------------------------------------------------------------------
# Board geometry / topology
#
#  0-----------1-----------2
#  |           |           |
#  |   8-------9-------10  |
#  |   |       |       |   |
#  |   |  16--17--18   |   |
#  7---15--23      19--11---3
#  |   |  22--21--20   |   |
#  |   |       |       |   |
#  |   14------13------12  |
#  |           |           |
#  6-----------5-----------4
# ---------------------------------------------------------------------------

# Grid coordinates (0..6) of each of the 24 points
my @XY = (
    [0,0],[3,0],[6,0],[6,3],[6,6],[3,6],[0,6],[0,3],      # outer ring  0-7
    [1,1],[3,1],[5,1],[5,3],[5,5],[3,5],[1,5],[1,3],      # middle ring 8-15
    [2,2],[3,2],[4,2],[4,3],[4,4],[3,4],[2,4],[2,3],      # inner ring 16-23
);

my (@ADJ, @MILLS, @MILLS_AT, @EDGES);

for my $r (0 .. 2) {
    my $base = 8 * $r;
    for my $k (0 .. 7) {
        my $a = $base + $k;
        my $b = $base + ($k + 1) % 8;
        push @{ $ADJ[$a] }, $b;
        push @{ $ADJ[$b] }, $a;
        push @EDGES, [$a, $b];
    }
    for my $s (0, 2, 4, 6) {
        push @MILLS, [ $base + $s, $base + $s + 1, $base + ($s + 2) % 8 ];
    }
}
for my $k (1, 3, 5, 7) {
    for my $r (0, 1) {
        my ($a, $b) = ($k + 8 * $r, $k + 8 * ($r + 1));
        push @{ $ADJ[$a] }, $b;
        push @{ $ADJ[$b] }, $a;
        push @EDGES, [$a, $b];
    }
    push @MILLS, [ $k, 8 + $k, 16 + $k ];
}
for my $m (@MILLS) {
    push @{ $MILLS_AT[$_] }, $m for @$m;
}

# ---------------------------------------------------------------------------
# Game state
# ---------------------------------------------------------------------------

my @NAME = ('', 'White', 'Black');

my @board;          # 0 empty, 1 white, 2 black
my @to_place;       # pieces still in hand, indexed by player
my @on_board;       # pieces on board, indexed by player
my $turn;           # 1 or 2
my $selected;       # selected point while moving (undef if none)
my $remove_mode;    # true when current player must remove an opponent piece
my $over;           # game finished?
my $winner;
my $vs_ai = 0;      # computer plays Black
my $ai_pending = 0;

my ($area, $status_label, $info_label);

sub new_game {
    @board    = (0) x 24;
    @to_place = (0, 9, 9);
    @on_board = (0, 0, 0);
    $turn        = 1;
    $selected    = undef;
    $remove_mode = 0;
    $over        = 0;
    $winner      = 0;
    refresh();
    schedule_ai();
}

# ---------------------------------------------------------------------------
# Rules
# ---------------------------------------------------------------------------

sub in_mill {
    my ($pt, $p) = @_;
    for my $m (@{ $MILLS_AT[$pt] }) {
        return 1 if $board[ $m->[0] ] == $p
                 && $board[ $m->[1] ] == $p
                 && $board[ $m->[2] ] == $p;
    }
    return 0;
}

sub can_fly {
    my $p = shift;
    return $to_place[$p] == 0 && $on_board[$p] == 3;
}

# Destination points available for the piece at $from (movement phase)
sub targets_for {
    my ($from) = @_;
    my $p = $board[$from];
    if (can_fly($p)) {
        return grep { $board[$_] == 0 } 0 .. 23;
    }
    return grep { $board[$_] == 0 } @{ $ADJ[$from] };
}

sub legal_moves {
    my ($p) = @_;
    return () if $to_place[$p] > 0;
    my @moves;
    for my $from (0 .. 23) {
        next unless $board[$from] == $p;
        push @moves, [ $from, $_ ] for targets_for($from);
    }
    return @moves;
}

# Opponent pieces that may be removed after a mill
sub removable {
    my ($opp) = @_;
    my @all   = grep { $board[$_] == $opp } 0 .. 23;
    my @loose = grep { !in_mill($_, $opp) } @all;
    return @loose ? @loose : @all;
}

sub end_turn {
    $turn = 3 - $turn;
    $selected = undef;
    # A player who cannot move loses
    if ($to_place[$turn] == 0 && !legal_moves($turn)) {
        $over   = 1;
        $winner = 3 - $turn;
    }
    refresh();
    schedule_ai();
}

sub after_action {
    my ($pt) = @_;
    if (in_mill($pt, $turn)) {
        $remove_mode = 1;
        refresh();
    } else {
        end_turn();
    }
}

sub do_place {
    my ($pt) = @_;
    $board[$pt] = $turn;
    $to_place[$turn]--;
    $on_board[$turn]++;
    after_action($pt);
}

sub do_move {
    my ($from, $to) = @_;
    $board[$to]   = $turn;
    $board[$from] = 0;
    $selected     = undef;
    after_action($to);
}

sub do_remove {
    my ($pt) = @_;
    my $opp = 3 - $turn;
    $board[$pt] = 0;
    $on_board[$opp]--;
    $remove_mode = 0;
    if ($to_place[$opp] + $on_board[$opp] < 3) {
        $over   = 1;
        $winner = $turn;
        refresh();
    } else {
        end_turn();
    }
}

# Handle a click (from human or AI) on point $pt
sub handle_point {
    my ($pt) = @_;
    return if $over;

    if ($remove_mode) {
        my $opp = 3 - $turn;
        my %ok = map { $_ => 1 } removable($opp);
        do_remove($pt) if $ok{$pt};
        return;
    }

    if ($to_place[$turn] > 0) {                 # placing phase
        do_place($pt) if $board[$pt] == 0;
        return;
    }

    # movement phase
    if ($board[$pt] == $turn) {
        $selected = $pt if targets_for($pt);
        refresh();
    }
    elsif ($board[$pt] == 0 && defined $selected) {
        my %ok = map { $_ => 1 } targets_for($selected);
        do_move($selected, $pt) if $ok{$pt};
    }
}

# ---------------------------------------------------------------------------
# Very simple computer opponent (plays Black)
# ---------------------------------------------------------------------------

sub would_form_mill {
    my ($pt, $p) = @_;
    for my $m (@{ $MILLS_AT[$pt] }) {
        my $n = 0;
        for my $q (@$m) { $n++ if $q != $pt && $board[$q] == $p }
        return 1 if $n == 2;
    }
    return 0;
}

sub schedule_ai {
    return unless $vs_ai && !$over && $turn == 2 && !$ai_pending;
    $ai_pending = 1;
    Glib::Timeout->add(600, sub {
        $ai_pending = 0;
        ai_step();
        return FALSE;
    });
}

sub ai_step {
    return unless $vs_ai && !$over && $turn == 2;
    my $me  = 2;
    my $opp = 1;

    if ($remove_mode) {
        my ($best, $best_score);
        for my $pt (shuffle removable($opp)) {
            my $score = rand(5);
            # prefer pieces that are part of a nearly complete line
            for my $m (@{ $MILLS_AT[$pt] }) {
                my $mine = grep { $board[$_] == $opp } @$m;
                my $free = grep { $board[$_] == 0 } @$m;
                $score += 10 if $mine == 2 && $free == 1;
                $score += 3  if $mine == 2;
            }
            $score += scalar(grep { $board[$_] == 0 } @{ $ADJ[$pt] });
            ($best, $best_score) = ($pt, $score)
                if !defined $best_score || $score > $best_score;
        }
        handle_point($best);
    }
    elsif ($to_place[$me] > 0) {
        my ($best, $best_score);
        for my $pt (shuffle grep { $board[$_] == 0 } 0 .. 23) {
            my $score = rand(3);
            $score += 100 if would_form_mill($pt, $me);
            $score += 50  if would_form_mill($pt, $opp);
            $score += scalar(grep { $board[$_] == 0 } @{ $ADJ[$pt] });
            ($best, $best_score) = ($pt, $score)
                if !defined $best_score || $score > $best_score;
        }
        handle_point($best);
    }
    else {
        my ($best, $best_score);
        for my $mv (shuffle legal_moves($me)) {
            my ($from, $to) = @$mv;
            $board[$from] = 0;
            my $score = rand(3);
            $score += 100 if would_form_mill($to, $me);
            $score += 50  if would_form_mill($to, $opp);
            $score += scalar(grep { $board[$_] == 0 } @{ $ADJ[$to] });
            $board[$from] = $me;
            ($best, $best_score) = ($mv, $score)
                if !defined $best_score || $score > $best_score;
        }
        if ($best) {
            $selected = $best->[0];
            handle_point($best->[1]);
        }
    }

    # If the AI still has to act (e.g. just formed a mill), go again
    schedule_ai();
}

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

sub refresh {
    my $text;
    if ($over) {
        $text = "Game over - $NAME[$winner] wins!";
    }
    elsif ($remove_mode) {
        $text = "$NAME[$turn]: mill! Remove an opponent's piece";
    }
    elsif ($to_place[$turn] > 0) {
        $text = "$NAME[$turn]: place a piece";
    }
    elsif (can_fly($turn)) {
        $text = "$NAME[$turn]: move (you can fly!)";
    }
    else {
        $text = "$NAME[$turn]: move a piece";
    }
    $status_label->set_markup("<big><b>$text</b></big>");
    $info_label->set_text(sprintf(
        "White - in hand: %d, on board: %d      Black - in hand: %d, on board: %d",
        $to_place[1], $on_board[1], $to_place[2], $on_board[2]));
    $area->queue_draw if $area;
}

sub geometry {
    my ($w) = @_;
    my $W = $w->get_allocated_width;
    my $H = $w->get_allocated_height;
    my $size = min($W, $H) - 60;
    $size = 60 if $size < 60;
    my $step = $size / 6;
    my $ox = ($W - 6 * $step) / 2;
    my $oy = ($H - 6 * $step) / 2;
    return ($ox, $oy, $step);
}

sub point_pos {
    my ($pt, $ox, $oy, $step) = @_;
    return ($ox + $XY[$pt][0] * $step, $oy + $XY[$pt][1] * $step);
}

sub draw_board {
    my ($w, $cr) = @_;
    my ($ox, $oy, $step) = geometry($w);
    my $W = $w->get_allocated_width;
    my $H = $w->get_allocated_height;

    # background
    $cr->set_source_rgb(0.86, 0.72, 0.50);
    $cr->rectangle(0, 0, $W, $H);
    $cr->fill;

    # lines
    $cr->set_source_rgb(0.25, 0.15, 0.05);
    $cr->set_line_width(3);
    for my $e (@EDGES) {
        my ($x1, $y1) = point_pos($e->[0], $ox, $oy, $step);
        my ($x2, $y2) = point_pos($e->[1], $ox, $oy, $step);
        $cr->move_to($x1, $y1);
        $cr->line_to($x2, $y2);
        $cr->stroke;
    }

    my $r = $step * 0.30;

    # which points get hints?
    my %hint_remove;
    my %hint_target;
    if (!$over && $remove_mode) {
        $hint_remove{$_} = 1 for removable(3 - $turn);
    }
    if (!$over && !$remove_mode) {
        if ($to_place[$turn] > 0) {
            $hint_target{$_} = 1 for grep { $board[$_] == 0 } 0 .. 23;
        }
        elsif (defined $selected) {
            $hint_target{$_} = 1 for targets_for($selected);
        }
    }

    for my $pt (0 .. 23) {
        my ($x, $y) = point_pos($pt, $ox, $oy, $step);

        if ($board[$pt] == 0) {
            $cr->set_source_rgb(0.25, 0.15, 0.05);
            $cr->arc($x, $y, $step * 0.08, 0, 2 * PI);
            $cr->fill;
            if ($hint_target{$pt}) {
                $cr->set_source_rgba(0.1, 0.6, 0.1, 0.55);
                $cr->arc($x, $y, $step * 0.14, 0, 2 * PI);
                $cr->fill;
            }
            next;
        }

        # piece
        my $white = $board[$pt] == 1;
        if ($white) { $cr->set_source_rgb(0.96, 0.96, 0.94) }
        else        { $cr->set_source_rgb(0.12, 0.12, 0.14) }
        $cr->arc($x, $y, $r, 0, 2 * PI);
        $cr->fill_preserve;
        $cr->set_source_rgb(0.1, 0.05, 0.0);
        $cr->set_line_width(2);
        $cr->stroke;

        # soft highlight
        if ($white) { $cr->set_source_rgba(0.7, 0.7, 0.7, 0.5) }
        else        { $cr->set_source_rgba(0.6, 0.6, 0.65, 0.35) }
        $cr->arc($x - $r * 0.25, $y - $r * 0.25, $r * 0.45, 0, 2 * PI);
        $cr->fill;

        # selected piece
        if (defined $selected && $selected == $pt) {
            $cr->set_source_rgb(0.95, 0.75, 0.05);
            $cr->set_line_width(4);
            $cr->arc($x, $y, $r + 5, 0, 2 * PI);
            $cr->stroke;
        }
        # removable piece
        if ($hint_remove{$pt}) {
            $cr->set_source_rgb(0.85, 0.1, 0.1);
            $cr->set_line_width(4);
            $cr->arc($x, $y, $r + 5, 0, 2 * PI);
            $cr->stroke;
        }
    }
}

sub on_click {
    my ($w, $ev) = @_;
    return TRUE if $over;
    return TRUE if $vs_ai && $turn == 2;

    my ($ox, $oy, $step) = geometry($w);
    my ($mx, $my) = ($ev->x, $ev->y);

    my ($hit, $best_d);
    for my $pt (0 .. 23) {
        my ($x, $y) = point_pos($pt, $ox, $oy, $step);
        my $d = sqrt(($mx - $x) ** 2 + ($my - $y) ** 2);
        if ($d < $step * 0.4 && (!defined $best_d || $d < $best_d)) {
            ($hit, $best_d) = ($pt, $d);
        }
    }
    handle_point($hit) if defined $hit;
    return TRUE;
}

sub build_ui {
    my $win = Gtk3::Window->new('toplevel');
    $win->set_title("Nine Men's Morris");
    $win->set_default_size(640, 720);
    $win->signal_connect(destroy => sub { Gtk3->main_quit });

    my $vbox = Gtk3::Box->new('vertical', 6);
    $vbox->set_border_width(8);
    $win->add($vbox);

    $status_label = Gtk3::Label->new('');
    $vbox->pack_start($status_label, FALSE, FALSE, 0);

    $area = Gtk3::DrawingArea->new;
    $area->set_size_request(420, 420);
    $area->set_hexpand(TRUE);
    $area->set_vexpand(TRUE);
    $area->add_events(['button-press-mask']);
    $area->signal_connect(draw => sub {
        my ($w, $cr) = @_;
        draw_board($w, $cr);
        return FALSE;
    });
    $area->signal_connect('button-press-event' => \&on_click);
    $vbox->pack_start($area, TRUE, TRUE, 0);

    $info_label = Gtk3::Label->new('');
    $vbox->pack_start($info_label, FALSE, FALSE, 0);

    my $hbox = Gtk3::Box->new('horizontal', 10);
    $vbox->pack_start($hbox, FALSE, FALSE, 0);

    my $new_btn = Gtk3::Button->new_with_label('New Game');
    $new_btn->signal_connect(clicked => sub { new_game() });
    $hbox->pack_start($new_btn, FALSE, FALSE, 0);

    my $ai_check = Gtk3::CheckButton->new_with_label('Play against computer (you are White)');
    $ai_check->signal_connect(toggled => sub {
        my $w = shift;
        $vs_ai = $w->get_active ? 1 : 0;
        new_game();
    });
    $hbox->pack_start($ai_check, FALSE, FALSE, 0);

    my $help = Gtk3::Label->new(
        "Place 9 pieces, then slide along lines. Three in a row removes an enemy piece. " .
        "With 3 pieces left you can fly. Reduce the enemy to 2 pieces or block them to win.");
    $help->set_line_wrap(TRUE);
    $help->set_max_width_chars(70);
    $vbox->pack_start($help, FALSE, FALSE, 0);

    $win->show_all;
}

build_ui();
new_game();
Gtk3->main;
