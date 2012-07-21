#!/usr/bin/perl

use strict;
use Sys::Hostname;
use IO::Socket;

my $addr = $ARGV[0] || '127.0.0.1';
my $port = $ARGV[1] || '3002';
my $hostname  = hostname;
my $buf = undef;

while (1) {
    my $sock = IO::Socket::INET->new(
            PeerAddr => $addr,
            PeerPort => $port,
            Proto    => 'tcp')
        or die "Can't connect: $!\n";

    $buf = <$sock>;
    $buf =~ s/[\s ]+$//g;

    if($buf eq "connected") {
        my $id = undef;
        if (open(AGENT_ID, "agent_id")) {
            $id = <AGENT_ID>;
        }
        print $sock "$id\n";

        $buf = <$sock>;
        $buf =~ s/[\s ]+$//g;
        my @data = split(/\|/, $buf);
        if($data[0] eq "registered") {
            open(AGENT_ID, ">agent_id");
            print AGENT_ID $data[1];
        }
    }

    close $sock;
    exit;
}
