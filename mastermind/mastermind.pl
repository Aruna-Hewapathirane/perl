#!/usr/bin/perl
#
# Mastermind - Perl + GTK3
#
# Requirements (Debian/Ubuntu):
#   sudo apt install libgtk3-perl libcairo-perl
# Or via CPAN: cpanm Gtk3 Cairo
#
# Run:  perl mastermind.pl
#
# How to play:
#   - The computer picks a secret code of 4 colored pegs (colors may repeat).
#   - Click a color in the palette (or press 1-6) to fill the next slot.
#   - Click a filled slot in the active row (or press Backspace) to remove it.
#   - Submit with the button or Enter.
#   - Black peg = right color, right place. White peg = right color, wrong place.
#   - You have 10 attempts.

use strict;
use warnings;
use Gtk3 -init;
use Cairo;
use constant PI => 4 * atan2(1, 1);

# ---------- Game configuration ----------
use constant {
    PEGS     => 4,
    MAXTRIES => 10,
};

my @COLORS = (
    [ 0.90, 0.22, 0.21 ],    # 1 red
    [ 0.96, 0.60, 0.11 ],    # 2 orange
    [ 0.98, 0.84, 0.18 ],    # 3 yellow
    [ 0.27, 0.69, 0.31 ],    # 4 green
    [ 0.13, 0.52, 0.90 ],    # 5 blue
    [ 0.60, 0.30, 0.75 ],    # 6 purple
);

# ---------- Layout (pixels) ----------
use constant {
    WIDTH      => 340,
    HEADER_H   => 70,
    ROW_H      => 44,
    PALETTE_H  => 70,
    PEG_R      => 16,
    PEG_X0     => 70,
    PEG_DX     => 46,
    FB_X       => 270,
    PAL_R      => 20,
    PAL_X0     => 42,
    PAL_DX     => 51,
};
use constant HEIGHT => HEADER_H + MAXTRIES * ROW_H + PALETTE_H;

# ---------- Game state ----------
my @secret;
my @history;    # each: { guess => [...], black => n, white => n }
my @current;    # PEGS slots, undef = empty
my $over;
my $won;

my ($area, $status, $win);

sub new_game {
    @secret  = map { int(rand(@COLORS)) } 1 .. PEGS;
    @history = ();
    @current = (undef) x PEGS;
    $over    = 0;
    $won     = 0;
    set_status("Pick " . PEGS . " colors, then press Submit.");
    $area->queue_draw if $area;
}

sub set_status {
    my ($text) = @_;
    $status->set_text($text) if $status;
}

# Returns (black, white)
sub score {
    my ($guess, $code) = @_;
    my $black = 0;
    my (@gc, @cc);
    for my $i (0 .. PEGS - 1) {
        if ($guess->[$i] == $code->[$i]) {
            $black++;
        } else {
            $gc[ $guess->[$i] ]++;
            $cc[ $code->[$i] ]++;
        }
    }
    my $white = 0;
    for my $c (0 .. $#COLORS) {
        my $g = $gc[$c] // 0;
        my $k = $cc[$c] // 0;
        $white += ($g < $k ? $g : $k);
    }
    return ($black, $white);
}

sub add_color {
    my ($c) = @_;
    return if $over;
    for my $i (0 .. PEGS - 1) {
        if (!defined $current[$i]) {
            $current[$i] = $c;
            last;
        }
    }
    $area->queue_draw;
}

sub remove_last {
    return if $over;
    for my $i (reverse 0 .. PEGS - 1) {
        if (defined $current[$i]) {
            $current[$i] = undef;
            last;
        }
    }
    $area->queue_draw;
}

sub submit_guess {
    return if $over;
    if (grep { !defined } @current) {
        set_status("Fill all " . PEGS . " slots first.");
        return;
    }
    my @guess = @current;
    my ($b, $w) = score(\@guess, \@secret);
    push @history, { guess => \@guess, black => $b, white => $w };
    @current = (undef) x PEGS;

    if ($b == PEGS) {
        $over = 1;
        $won  = 1;
        my $n = scalar @history;
        set_status("You cracked the code in $n " . ($n == 1 ? "try" : "tries") . "! \x{1F389}");
    } elsif (@history >= MAXTRIES) {
        $over = 1;
        set_status("Out of tries. The secret code is revealed above.");
    } else {
        my $left = MAXTRIES - @history;
        set_status("$b black, $w white. $left " . ($left == 1 ? "try" : "tries") . " left.");
    }
    $area->queue_draw;
}

# ---------- Drawing helpers ----------
sub peg_center {
    my ($row, $col) = @_;
    return (PEG_X0 + $col * PEG_DX, HEADER_H + $row * ROW_H + ROW_H / 2);
}

sub circle {
    my ($cr, $x, $y, $r, $color) = @_;
    $cr->new_path;
    $cr->arc($x, $y, $r, 0, 2 * PI);
    if (defined $color) {
        $cr->set_source_rgb(@{ $COLORS[$color] });
        $cr->fill_preserve;
        $cr->set_source_rgba(0, 0, 0, 0.45);
        $cr->set_line_width(1.5);
        $cr->stroke;
        # highlight
        $cr->new_path;
        $cr->arc($x - $r * 0.3, $y - $r * 0.3, $r * 0.28, 0, 2 * PI);
        $cr->set_source_rgba(1, 1, 1, 0.35);
        $cr->fill;
    } else {
        $cr->set_source_rgb(0.20, 0.22, 0.26);
        $cr->fill_preserve;
        $cr->set_source_rgb(0.35, 0.38, 0.43);
        $cr->set_line_width(1.5);
        $cr->stroke;
    }
}

sub centered_text {
    my ($cr, $text, $x, $y, $size, @rgba) = @_;
    $cr->select_font_face("Sans", "normal", "bold");
    $cr->set_font_size($size);
    my $e = $cr->text_extents($text);
    $cr->set_source_rgba(@rgba);
    $cr->move_to($x - $e->{width} / 2 - $e->{x_bearing},
                 $y - $e->{height} / 2 - $e->{y_bearing});
    $cr->show_text($text);
}

sub rounded_rect {
    my ($cr, $x, $y, $w, $h, $r) = @_;
    $cr->new_path;
    $cr->arc($x + $w - $r, $y + $r,      $r, -PI / 2, 0);
    $cr->arc($x + $w - $r, $y + $h - $r, $r, 0,       PI / 2);
    $cr->arc($x + $r,      $y + $h - $r, $r, PI / 2,  PI);
    $cr->arc($x + $r,      $y + $r,      $r, PI,      3 * PI / 2);
    $cr->close_path;
}

sub draw_feedback {
    my ($cr, $row, $black, $white) = @_;
    my $cy = HEADER_H + $row * ROW_H + ROW_H / 2;
    my @offsets = ([-10, -9], [10, -9], [-10, 9], [10, 9]);
    my $k = 0;
    for my $o (@offsets) {
        my ($x, $y) = (FB_X + $o->[0], $cy + $o->[1]);
        $cr->new_path;
        $cr->arc($x, $y, 6, 0, 2 * PI);
        if ($k < $black) {
            $cr->set_source_rgb(0.05, 0.05, 0.05);
            $cr->fill_preserve;
            $cr->set_source_rgb(0.7, 0.7, 0.7);
        } elsif ($k < $black + $white) {
            $cr->set_source_rgb(0.97, 0.97, 0.97);
            $cr->fill_preserve;
            $cr->set_source_rgb(0.5, 0.5, 0.5);
        } else {
            $cr->set_source_rgb(0.20, 0.22, 0.26);
            $cr->fill_preserve;
            $cr->set_source_rgb(0.30, 0.33, 0.38);
        }
        $cr->set_line_width(1);
        $cr->stroke;
        $k++;
    }
}

sub on_draw {
    my ($widget, $cr) = @_;

    # Background
    $cr->set_source_rgb(0.12, 0.13, 0.16);
    $cr->paint;

    # --- Secret code header ---
    rounded_rect($cr, 14, 10, WIDTH - 28, HEADER_H - 20, 10);
    $cr->set_source_rgb(0.17, 0.19, 0.23);
    $cr->fill;

    my $hy = HEADER_H / 2;
    centered_text($cr, "CODE", 38, $hy, 11, 0.6, 0.65, 0.7, 1);
    for my $i (0 .. PEGS - 1) {
        my $x = PEG_X0 + $i * PEG_DX;
        if ($over) {
            circle($cr, $x, $hy, PEG_R, $secret[$i]);
            centered_text($cr, $secret[$i] + 1, $x, $hy, 12, 1, 1, 1, 0.9);
        } else {
            circle($cr, $x, $hy, PEG_R, undef);
            centered_text($cr, "?", $x, $hy, 14, 0.5, 0.55, 0.6, 1);
        }
    }
    if ($over) {
        centered_text($cr, $won ? "WIN" : "LOSE", FB_X, $hy, 13,
                      $won ? (0.4, 0.9, 0.5, 1) : (0.95, 0.4, 0.4, 1));
    }

    # --- Board rows ---
    my $active = scalar @history;
    for my $r (0 .. MAXTRIES - 1) {
        my $y = HEADER_H + $r * ROW_H;

        if ($r == $active && !$over) {
            rounded_rect($cr, 8, $y + 2, WIDTH - 16, ROW_H - 4, 8);
            $cr->set_source_rgba(1, 1, 1, 0.08);
            $cr->fill_preserve;
            $cr->set_source_rgba(1, 1, 1, 0.25);
            $cr->set_line_width(1.5);
            $cr->stroke;
        }

        centered_text($cr, $r + 1, 28, $y + ROW_H / 2, 12, 0.5, 0.55, 0.6, 1);

        if ($r < @history) {
            my $h = $history[$r];
            for my $c (0 .. PEGS - 1) {
                my ($x, $cy) = peg_center($r, $c);
                circle($cr, $x, $cy, PEG_R, $h->{guess}[$c]);
                centered_text($cr, $h->{guess}[$c] + 1, $x, $cy, 12, 1, 1, 1, 0.9);
            }
            draw_feedback($cr, $r, $h->{black}, $h->{white});
        } elsif ($r == $active && !$over) {
            for my $c (0 .. PEGS - 1) {
                my ($x, $cy) = peg_center($r, $c);
                circle($cr, $x, $cy, PEG_R, $current[$c]);
                if (defined $current[$c]) {
                    centered_text($cr, $current[$c] + 1, $x, $cy, 12, 1, 1, 1, 0.9);
                }
            }
            draw_feedback($cr, $r, 0, 0);
        } else {
            for my $c (0 .. PEGS - 1) {
                my ($x, $cy) = peg_center($r, $c);
                circle($cr, $x, $cy, PEG_R - 4, undef);
            }
        }
    }

    # --- Palette ---
    my $py = HEADER_H + MAXTRIES * ROW_H + PALETTE_H / 2;
    $cr->set_source_rgba(1, 1, 1, 0.1);
    $cr->set_line_width(1);
    $cr->move_to(14, HEADER_H + MAXTRIES * ROW_H + 4);
    $cr->line_to(WIDTH - 14, HEADER_H + MAXTRIES * ROW_H + 4);
    $cr->stroke;

    for my $k (0 .. $#COLORS) {
        my $x = PAL_X0 + $k * PAL_DX;
        circle($cr, $x, $py, PAL_R, $k);
        centered_text($cr, $k + 1, $x, $py, 14, 1, 1, 1, 0.95);
    }

    return 0;
}

sub on_click {
    my ($widget, $event) = @_;
    return 0 unless $event->button == 1;
    my ($mx, $my) = ($event->x, $event->y);

    # Palette hit test
    my $py = HEADER_H + MAXTRIES * ROW_H + PALETTE_H / 2;
    for my $k (0 .. $#COLORS) {
        my $x = PAL_X0 + $k * PAL_DX;
        if (($mx - $x)**2 + ($my - $py)**2 <= PAL_R**2) {
            add_color($k);
            return 1;
        }
    }

    # Active row slot hit test (click to clear a slot)
    if (!$over) {
        my $row = scalar @history;
        for my $c (0 .. PEGS - 1) {
            my ($x, $y) = peg_center($row, $c);
            if (($mx - $x)**2 + ($my - $y)**2 <= PEG_R**2) {
                $current[$c] = undef;
                $area->queue_draw;
                return 1;
            }
        }
    }
    return 1;
}

sub on_key {
    my ($widget, $event) = @_;
    my $k = $event->keyval;

    if ($k >= ord('1') && $k <= ord('0') + @COLORS) {
        add_color($k - ord('1'));
        return 1;
    }
    if ($k == 0xFF08) {                          # BackSpace
        remove_last();
        return 1;
    }
    if ($k == 0xFF0D || $k == 0xFF8D) {          # Return / KP_Enter
        submit_guess();
        return 1;
    }
    return 0;
}

# ---------- Build the UI ----------
$win = Gtk3::Window->new('toplevel');
$win->set_title("Mastermind");
$win->set_resizable(0);
$win->set_border_width(8);
$win->signal_connect(destroy => sub { Gtk3->main_quit });
$win->signal_connect('key-press-event' => \&on_key);

my $vbox = Gtk3::Box->new('vertical', 8);
$win->add($vbox);

$area = Gtk3::DrawingArea->new;
$area->set_size_request(WIDTH, HEIGHT);
$area->add_events(['button-press-mask']);
$area->signal_connect(draw                => \&on_draw);
$area->signal_connect('button-press-event' => \&on_click);
$vbox->pack_start($area, 0, 0, 0);

$status = Gtk3::Label->new("");
$status->set_xalign(0);
$status->set_line_wrap(1);
$status->set_size_request(WIDTH, -1);
$vbox->pack_start($status, 0, 0, 0);

my $bbox = Gtk3::Box->new('horizontal', 6);
$bbox->set_homogeneous(1);
$vbox->pack_start($bbox, 0, 0, 0);

my $btn_submit = Gtk3::Button->new_with_label("Submit");
my $btn_undo   = Gtk3::Button->new_with_label("Undo");
my $btn_new    = Gtk3::Button->new_with_label("New Game");
for my $b ($btn_submit, $btn_undo, $btn_new) {
    $b->set_can_focus(0);    # keep keyboard input on the window
    $bbox->pack_start($b, 1, 1, 0);
}
$btn_submit->signal_connect(clicked => \&submit_guess);
$btn_undo->signal_connect(clicked   => \&remove_last);
$btn_new->signal_connect(clicked    => \&new_game);

new_game();
$win->show_all;
Gtk3->main;
