#!/usr/bin/perl

use strict;
use IO::Socket;

my $addr = $ARGV[0] || '127.0.0.1';
my $general_port = $ARGV[1] || '3002';
my $software_port = $ARGV[2] || '9002';
my $buf = undef;

my ($stat, $err) = start_sw_process($software_port);
if ($stat eq "error") {
	print "$err\n";
	exit 1;
}

while (1) {
    my $sock = IO::Socket::INET->new(
            PeerAddr => $addr,
            PeerPort => $general_port,
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
    close AGENT_ID;
    sleep(300);
}

sub start_sw_process {
    my $port = shift;

	defined(my $pid = fork) or return("error", "Can't fork: $!");

    if($pid == 0) {
        my $sock = IO::Socket::INET->new( 
            Listen    => 5,
            LocalPort => $port,
            Timeout   => 60*1,
            Reuse     => 1
        );
        exit 1 if(!$sock);

        while(1) {
            next unless my $session = $sock->accept;

            my $file_name = <$session>;
            $file_name =~ s/[\s ]+$//g;
            print $session "got file name\n";

            my @recv = <$session>;
            open(OUT, ">/tmp/$file_name");
            binmode(OUT);
            print OUT @recv;

            close OUT;
            close $session;
        }

        close $sock;
        exit 0;
    }
}
