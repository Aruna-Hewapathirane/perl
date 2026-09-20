#!/usr/bin/perl
use strict;
use warnings;
use Tk;

# Create the main window
my $mw = MainWindow->new;
$mw->title("My Perl GUI");
$mw->geometry("600x400");

# Add a label widget
my $label = $mw->Label(-text => "Hello, World from Perl!") ->pack;

# Add a button widget to exit the app
my $button = $mw->Button(
    -text    => "Close Window",
    -command => sub { exit }
) ->pack;

# MainLoop starts the GUI and handles events
MainLoop;

