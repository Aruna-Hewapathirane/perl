#!/usr/bin/env perl
# QIX-style territory game  --  Perl + Gtk3 + Cairo
#
# Controls
#   Arrows / WASD ... move along the edges
#   SPACE (hold) ... start drawing a line into open space
#   SHIFT (hold) ... slow draw (half speed, double points)
#   P ............... pause        ENTER ... restart after game over
#   ESC ............. quit
#
# Enclose 75% of the field to clear the level. Avoid the Qix (the blue
# scribble), the Sparx (red markers crawling along the edges), and never let
# the Qix touch your unfinished line.

use strict;
use warnings;
use Gtk3 -init;
use Cairo;
use Glib qw(TRUE FALSE);

use constant {
    GW      => 110,   # grid width  (cells)
    GH      => 70,    # grid height (cells)
    CELL    => 5,     # pixels per cell
    PAD     => 12,
    HUD     => 26,
    TARGET  => 75,    # % needed to win a level
    TICK_MS => 35,
};

my $PLAYER_NAME = 'A.TROTT';
my %DIR = (L => [-1, 0], R => [1, 0], U => [0, -1], D => [0, 1]);
my %KEYDIR = (
    0xff51 => 'L', 0x61 => 'L',
    0xff53 => 'R', 0x64 => 'R',
    0xff52 => 'U', 0x77 => 'U',
    0xff54 => 'D', 0x73 => 'D',
);

# grid: 0 = empty, 1 = claimed, 2 = line being drawn
my @g;
my @pts;                 # polyline of the line currently being drawn
my @dirstack;            # held direction keys (last = active)
my ($fire, $slow, $paused) = (0, 0, 0);
my ($px, $py, $drawing) = (0, 0, 0);
my ($score, $lives, $level, $claimed, $pct) = (0, 3, 1, 0, 0);
my ($state, $pause, $frame, $dirty) = ('play', 0, 0, 1);
my (@qix, @qhist, @sparx);
my $area;                # the Gtk3::DrawingArea
my $total = (GW - 2) * (GH - 2);
my $cache = Cairo::ImageSurface->create('argb32', GW * CELL, GH * CELL);

# ---------------------------------------------------------------- grid helpers

sub cell {
    my ($x, $y) = @_;
    return 1 if $x < 0 || $y < 0 || $x >= GW || $y >= GH;
    return $g[$y][$x];
}

# a claimed cell touching open space (or the current line) can be walked on
sub is_edge {
    my ($x, $y) = @_;
    return 0 unless cell($x, $y) == 1;
    for my $dy (-1 .. 1) {
        for my $dx (-1 .. 1) {
            next unless $dx || $dy;
            my ($nx, $ny) = ($x + $dx, $y + $dy);
            next if $nx < 0 || $ny < 0 || $nx >= GW || $ny >= GH;
            return 1 if $g[$ny][$nx] != 1;
        }
    }
    return 0;
}

sub recount {
    $claimed = 0;
    for my $y (1 .. GH - 2) {
        for my $x (1 .. GW - 2) { $claimed++ if $g[$y][$x] == 1 }
    }
    $pct = int(100 * $claimed / $total);
}

# ---------------------------------------------------------------- game setup

sub new_game {
    ($score, $lives, $level) = (0, 3, 1);
    new_level();
}

sub new_level {
    @g = ();
    for my $y (0 .. GH - 1) {
        for my $x (0 .. GW - 1) {
            $g[$y][$x] = ($x == 0 || $y == 0 || $x == GW - 1 || $y == GH - 1) ? 1 : 0;
        }
    }
    my $sp = 0.4 + 0.05 * $level;   # Qix speed
    $sp = 0.8 if $sp > 0.8;
    @qix = (
        { x => GW * 0.40, y => GH * 0.40, vx =>  $sp,       vy => $sp * 0.6 },
        { x => GW * 0.60, y => GH * 0.60, vx => -$sp * 0.7, vy => $sp },
    );
    @qhist = ();
    reset_actors();
    recount();
    $dirty = 1;
    $state = 'play';
}

sub reset_actors {
    ($px, $py) = (int(GW / 2), GH - 1);
    $drawing = 0;
    @pts = ();
    @sparx = (
        { x => int(GW / 2) - 10, y => 0, dx => -1, dy => 0 },
        { x => int(GW / 2) + 10, y => 0, dx =>  1, dy => 0 },
    );
}

# ---------------------------------------------------------------- player

sub move_player {
    my $d = @dirstack ? $dirstack[-1] : undef;
    return unless $d;
    my ($dx, $dy) = @{ $DIR{$d} };
    my ($nx, $ny) = ($px + $dx, $py + $dy);
    return if $nx < 0 || $ny < 0 || $nx >= GW || $ny >= GH;
    my $t = $g[$ny][$nx];

    if ($drawing) {
        if ($t == 0) {
            $g[$ny][$nx] = 2;
            push @pts, [$nx, $ny];
            ($px, $py) = ($nx, $ny);
        }
        elsif ($t == 1) {
            ($px, $py) = ($nx, $ny);
            push @pts, [$nx, $ny];
            capture();
        }
        # t == 2: can't cross own line
    }
    else {
        if ($t == 1 && is_edge($nx, $ny)) {
            ($px, $py) = ($nx, $ny);
        }
        elsif ($t == 0 && $fire) {
            $drawing = 1;
            @pts = ([$px, $py]);
            $g[$ny][$nx] = 2;
            push @pts, [$nx, $ny];
            ($px, $py) = ($nx, $ny);
        }
    }
}

sub capture {
    my $added = 0;
    for my $p (@pts) {
        my ($x, $y) = @$p;
        if ($g[$y][$x] == 2) { $g[$y][$x] = 1; $added++ }
    }
    @pts = ();
    $drawing = 0;

    # flood-fill the open regions that contain a Qix end; fill everything else
    my (@keep, @stack);
    for my $q (@qix) {
        my ($x, $y) = (int($q->{x}), int($q->{y}));
        if (cell($x, $y) == 0 && !$keep[$y][$x]) {
            $keep[$y][$x] = 1;
            push @stack, [$x, $y];
        }
    }
    while (my $c = pop @stack) {
        for my $d (values %DIR) {
            my ($nx, $ny) = ($c->[0] + $d->[0], $c->[1] + $d->[1]);
            next if $nx < 0 || $ny < 0 || $nx >= GW || $ny >= GH;
            next if $g[$ny][$nx] != 0 || $keep[$ny][$nx];
            $keep[$ny][$nx] = 1;
            push @stack, [$nx, $ny];
        }
    }
    for my $y (0 .. GH - 1) {
        for my $x (0 .. GW - 1) {
            if ($g[$y][$x] == 0 && !$keep[$y][$x]) { $g[$y][$x] = 1; $added++ }
        }
    }

    $score += $added * ($slow ? 2 : 1);
    recount();
    $dirty = 1;
    fix_player();
}

# nearest walkable edge cell to (x,y), searching through claimed land
sub nearest_edge {
    my ($x0, $y0) = @_;
    my %seen = ("$x0,$y0" => 1);
    my @queue = ([$x0, $y0]);
    while (my $c = shift @queue) {
        return @$c if is_edge(@$c);
        for my $d (values %DIR) {
            my ($nx, $ny) = ($c->[0] + $d->[0], $c->[1] + $d->[1]);
            next if $nx < 0 || $ny < 0 || $nx >= GW || $ny >= GH;
            next if $seen{"$nx,$ny"}++ || $g[$ny][$nx] != 1;
            push @queue, [$nx, $ny];
        }
    }
    return ($x0, $y0);
}

# make sure the player stands on a walkable edge cell
sub fix_player {
    return if is_edge($px, $py);
    ($px, $py) = nearest_edge($px, $py);
}

# put the player and Sparx back on the edge after a death
sub respawn {
    reset_actors();
    ($px, $py) = nearest_edge($px, $py);
    for my $s (@sparx) { ($s->{x}, $s->{y}) = nearest_edge($s->{x}, $s->{y}) }
    # keep the Sparx away from the player's spawn point
    for my $s (@sparx) {
        if (abs($s->{x} - $px) + abs($s->{y} - $py) < 15) {
            my @all;
            for my $y (0 .. GH - 1) {
                for my $x (0 .. GW - 1) {
                    push @all, [$x, $y]
                        if is_edge($x, $y) && abs($x - $px) + abs($y - $py) >= 30;
                }
            }
            ($s->{x}, $s->{y}) = @{ $all[int rand @all] } if @all;
        }
    }
}

# ---------------------------------------------------------------- enemies

sub move_qix {
    for my $q (@qix) {
        if (rand() < 0.08) {
            $q->{vx} += rand(0.4) - 0.2;
            $q->{vy} += rand(0.4) - 0.2;
            for my $k (qw(vx vy)) {
                $q->{$k} =  0.9 if $q->{$k} >  0.9;
                $q->{$k} = -0.9 if $q->{$k} < -0.9;
            }
        }
        my $nx = $q->{x} + $q->{vx};
        my $c  = cell(int($nx), int($q->{y}));
        if    ($c == 0) { $q->{x} = $nx }
        elsif ($c == 2) { die_player(); return }
        else            { $q->{vx} = -$q->{vx} }

        my $ny = $q->{y} + $q->{vy};
        $c = cell(int($q->{x}), int($ny));
        if    ($c == 0) { $q->{y} = $ny }
        elsif ($c == 2) { die_player(); return }
        else            { $q->{vy} = -$q->{vy} }
    }

    # does the Qix line touch the unfinished line?
    my ($q1, $q2) = @qix;
    for my $i (0 .. 24) {
        my $t = $i / 24;
        my $x = int($q1->{x} + ($q2->{x} - $q1->{x}) * $t);
        my $y = int($q1->{y} + ($q2->{y} - $q1->{y}) * $t);
        if (cell($x, $y) == 2) { die_player(); return }
    }

    if ($frame % 2 == 0) {
        unshift @qhist, [$q1->{x}, $q1->{y}, $q2->{x}, $q2->{y}];
        pop @qhist while @qhist > 8;
    }
}

sub move_sparx {
    for my $s (@sparx) {
        my @opts;
        for my $d (values %DIR) {
            my ($dx, $dy) = @$d;
            next if $dx == -$s->{dx} && $dy == -$s->{dy};
            push @opts, $d if is_edge($s->{x} + $dx, $s->{y} + $dy);
        }
        my $pick;
        if (@opts) {
            my ($straight) = grep { $_->[0] == $s->{dx} && $_->[1] == $s->{dy} } @opts;
            $pick = ($straight && rand() < 0.75) ? $straight : $opts[int rand @opts];
        }
        elsif (is_edge($s->{x} - $s->{dx}, $s->{y} - $s->{dy})) {
            $pick = [-$s->{dx}, -$s->{dy}];
        }
        if ($pick) {
            ($s->{dx}, $s->{dy}) = @$pick;
            $s->{x} += $s->{dx};
            $s->{y} += $s->{dy};
        }
        else {
            # stranded (the edge was filled in): hop to a random edge cell
            my @all;
            for my $y (0 .. GH - 1) {
                for my $x (0 .. GW - 1) { push @all, [$x, $y] if is_edge($x, $y) }
            }
            if (@all) {
                my $c = $all[int rand @all];
                ($s->{x}, $s->{y}) = @$c;
            }
        }
    }
}

sub check_sparx_hit {
    for my $s (@sparx) {
        if ($s->{x} == $px && $s->{y} == $py) { die_player(); return }
    }
}

sub die_player {
    return unless $state eq 'play';
    $lives--;
    for my $p (@pts) {
        my ($x, $y) = @$p;
        $g[$y][$x] = 0 if $g[$y][$x] == 2;
    }
    @pts = ();
    $drawing = 0;
    $state = 'dead';
    $pause = 30;
}

# ---------------------------------------------------------------- main tick

sub tick {
    $frame++;
    if (!$paused) {
        if ($state eq 'play') {
            if (!$slow || $frame % 2 == 0) {
                move_player();
                check_sparx_hit() if $state eq 'play';
            }
            move_qix() if $state eq 'play';
            my $div = $level >= 4 ? 3 : 4;   # Sparx move every N ticks
            if ($state eq 'play' && $frame % $div == 0) {
                move_sparx();
                check_sparx_hit();
            }
            if ($state eq 'play' && $pct >= TARGET) {
                $score += 100 * $level;
                $state = 'level';
                $pause = 60;
            }
        }
        elsif ($state eq 'dead') {
            if (--$pause <= 0) {
                if ($lives <= 0) { $state = 'over' }
                else             { respawn(); $state = 'play' }
            }
        }
        elsif ($state eq 'level') {
            if (--$pause <= 0) { $level++; new_level() }
        }
    }
    $area->queue_draw if $area;
    return TRUE;
}

# ---------------------------------------------------------------- rendering

sub refresh_cache {
    my $c = Cairo::Context->create($cache);
    $c->set_source_rgb(0.75, 0.75, 0.75);
    $c->paint;

    $c->set_source_rgb(0.25, 0.25, 0.90);
    for my $y (0 .. GH - 1) {
        for my $x (0 .. GW - 1) {
            next unless $g[$y][$x] == 1;
            $c->rectangle($x * CELL, $y * CELL, CELL, CELL);
        }
    }
    $c->fill;

    # black outline where claimed land meets open space
    $c->set_source_rgb(0, 0, 0);
    $c->set_line_width(1.5);
    for my $y (0 .. GH - 1) {
        for my $x (0 .. GW - 1) {
            next unless $g[$y][$x] == 1;
            my ($x0, $y0, $x1, $y1) = ($x * CELL, $y * CELL, ($x + 1) * CELL, ($y + 1) * CELL);
            if ($y > 0      && $g[$y - 1][$x] == 0) { $c->move_to($x0, $y0); $c->line_to($x1, $y0) }
            if ($y < GH - 1 && $g[$y + 1][$x] == 0) { $c->move_to($x0, $y1); $c->line_to($x1, $y1) }
            if ($x > 0      && $g[$y][$x - 1] == 0) { $c->move_to($x0, $y0); $c->line_to($x0, $y1) }
            if ($x < GW - 1 && $g[$y][$x + 1] == 0) { $c->move_to($x1, $y0); $c->line_to($x1, $y1) }
        }
    }
    $c->stroke;
    $dirty = 0;
}

sub center_text {
    my ($cr, $str, $cx, $cy, $size) = @_;
    $cr->set_font_size($size);
    my $e = $cr->text_extents($str);
    my $x = $cx - $e->{width} / 2;
    $cr->set_source_rgb(0, 0, 0);
    $cr->move_to($x + 2, $cy + 2);
    $cr->show_text($str);
    $cr->set_source_rgb(1, 1, 1);
    $cr->move_to($x, $cy);
    $cr->show_text($str);
}

sub render {
    my ($cr) = @_;
    my ($fx, $fy) = (PAD, PAD + HUD + 4);
    my ($fw, $fh) = (GW * CELL, GH * CELL);

    # bezel
    $cr->set_source_rgb(0.85, 0.85, 0.85);
    $cr->paint;

    # HUD bar
    $cr->set_source_rgb(0.75, 0.75, 0.75);
    $cr->rectangle($fx, PAD, $fw, HUD);
    $cr->fill;
    $cr->set_source_rgb(0.25, 0.80, 0.25);
    $cr->rectangle($fx, PAD, $fw * 0.75, HUD);
    $cr->fill;
    $cr->set_source_rgb(0, 0, 0);
    $cr->set_line_width(1);
    $cr->rectangle($fx + 0.5, PAD + 0.5, $fw - 1, HUD - 1);
    $cr->stroke;

    $cr->select_font_face('Monospace', 'normal', 'bold');
    $cr->set_font_size(18);
    $cr->set_source_rgb(0, 0, 0);
    $cr->move_to($fx + 6, PAD + HUD - 7);
    $cr->show_text($PLAYER_NAME);
    for my $i (0 .. $lives - 1) {
        $cr->arc($fx + 150 + $i * 20, PAD + HUD / 2, 3, 0, 6.2832);
        $cr->fill;
    }
    $cr->move_to($fx + 215, PAD + HUD - 6);
    $cr->set_font_size(22);
    $cr->show_text(sprintf('%2d%%', $pct));
    $cr->set_font_size(18);
    $cr->move_to($fx + $fw - 90, PAD + HUD - 7);
    $cr->show_text(sprintf('%06d', $score));

    # playfield
    refresh_cache() if $dirty;
    $cr->set_source_surface($cache, $fx, $fy);
    $cr->paint;

    # Qix: fading history of lines makes the hatched look
    for my $i (reverse 0 .. $#qhist) {
        my $h = $qhist[$i];
        my $a = 1.0 - $i * 0.10;
        $cr->set_source_rgba(0.20, 0.20, 0.85, $a);
        $cr->set_line_width(1);
        $cr->move_to($fx + $h->[0] * CELL, $fy + $h->[1] * CELL);
        $cr->line_to($fx + $h->[2] * CELL, $fy + $h->[3] * CELL);
        $cr->stroke;
    }

    # unfinished line
    if (@pts) {
        $cr->set_source_rgb(0, 0, 0);
        $cr->set_line_width(2);
        $cr->set_line_join('round');
        my $first = 1;
        for my $p (@pts) {
            my ($x, $y) = ($fx + ($p->[0] + 0.5) * CELL, $fy + ($p->[1] + 0.5) * CELL);
            if ($first) { $cr->move_to($x, $y); $first = 0 } else { $cr->line_to($x, $y) }
        }
        $cr->stroke;
    }

    # player
    {
        my ($x, $y) = ($fx + ($px + 0.5) * CELL, $fy + ($py + 0.5) * CELL);
        if ($state eq 'dead') { $cr->set_source_rgb(1, 0.2, 0.2) }
        else                  { $cr->set_source_rgb(1, 1, 1) }
        $cr->arc($x, $y, 4.5, 0, 6.2832);
        $cr->fill_preserve;
        $cr->set_source_rgb(0, 0, 0);
        $cr->set_line_width(1);
        $cr->stroke;
    }

    # field frame
    $cr->set_source_rgb(0, 0, 0);
    $cr->set_line_width(2);
    $cr->rectangle($fx - 1, $fy - 1, $fw + 2, $fh + 2);
    $cr->stroke;

    # Sparx: flickering red/yellow sparks, drawn last so they sit on top
    for my $s (@sparx) {
        my ($x, $y) = ($fx + ($s->{x} + 0.5) * CELL, $fy + ($s->{y} + 0.5) * CELL);
        my $r = ($frame % 4 < 2) ? 9 : 7;
        $cr->set_line_join('miter');
        for my $pass (0, 1) {
            my ($rad, @col) = $pass ? ($r * 0.55, 1.0, 0.9, 0.2) : ($r, 0.95, 0.1, 0.1);
            $cr->new_path;
            for my $i (0 .. 7) {
                my $ang = $i * 3.14159265 / 4 + $frame * 0.3;
                my $rr  = ($i % 2) ? $rad * 0.45 : $rad;
                my ($sx, $sy) = ($x + cos($ang) * $rr, $y + sin($ang) * $rr);
                if ($i == 0) { $cr->move_to($sx, $sy) } else { $cr->line_to($sx, $sy) }
            }
            $cr->close_path;
            $cr->set_source_rgb(@col);
            $cr->fill_preserve;
            $cr->set_source_rgb(0, 0, 0);
            $cr->set_line_width(1);
            $cr->stroke;
        }
    }

    # overlays
    my ($cx, $cy) = ($fx + $fw / 2, $fy + $fh / 2);
    $cr->select_font_face('Monospace', 'normal', 'bold');
    if    ($paused)          { center_text($cr, 'PAUSED', $cx, $cy, 40) }
    elsif ($state eq 'over') {
        center_text($cr, 'GAME OVER', $cx, $cy, 44);
        center_text($cr, 'press ENTER to play again', $cx, $cy + 34, 18);
    }
    elsif ($state eq 'level') { center_text($cr, "LEVEL $level CLEARED!", $cx, $cy, 34) }
}

# ---------------------------------------------------------------- UI

my $win = Gtk3::Window->new('toplevel');
$win->set_title('QIX');
$win->set_resizable(FALSE);
$win->signal_connect(destroy => sub { Gtk3->main_quit });

$area = Gtk3::DrawingArea->new;
$area->set_size_request(GW * CELL + 2 * PAD, GH * CELL + 2 * PAD + HUD + 4);
$area->signal_connect(draw => sub {
    my ($w, $cr) = @_;
    render($cr);
    return FALSE;
});
$win->add($area);

sub norm_key {
    my $k = shift;
    $k += 32 if $k >= 65 && $k <= 90;
    return $k;
}

$win->signal_connect('key-press-event' => sub {
    my ($w, $e) = @_;
    my $k = norm_key($e->keyval);
    if (my $d = $KEYDIR{$k}) {
        @dirstack = grep { $_ ne $d } @dirstack;
        push @dirstack, $d;
    }
    elsif ($k == 0x20)                      { $fire = 1 }
    elsif ($k == 0xffe1 || $k == 0xffe2)    { $slow = 1 }
    elsif ($k == 0x70)                      { $paused = !$paused }
    elsif ($k == 0xff0d || $k == 0xff8d)    { new_game() if $state eq 'over' }
    elsif ($k == 0xff1b)                    { Gtk3->main_quit }
    return TRUE;
});

$win->signal_connect('key-release-event' => sub {
    my ($w, $e) = @_;
    my $k = norm_key($e->keyval);
    if (my $d = $KEYDIR{$k})                { @dirstack = grep { $_ ne $d } @dirstack }
    elsif ($k == 0x20)                      { $fire = 0 }
    elsif ($k == 0xffe1 || $k == 0xffe2)    { $slow = 0 }
    return TRUE;
});

new_game();
Glib::Timeout->add(TICK_MS, \&tick);
$win->show_all;
Gtk3->main;
