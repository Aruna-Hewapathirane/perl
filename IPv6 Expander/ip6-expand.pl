# Sent by stanrifkin in #pascal
# Sat Sep 12 2026

#!/usr/bin/env perl
use feature qw(say);
use Socket  qw(inet_pton AF_INET6);

@ip6s = split /\n/, `ip a | grep inet6`;

for (@ip6s) {
    s/^\s+//;
    $addr = (split)[1];
    $addr = substr $addr, 0, index $addr, "/";
    $addr = join ":", unpack "H4" x 8, inet_pton AF_INET6, $addr;
    say $addr;
}
