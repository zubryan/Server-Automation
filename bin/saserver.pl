#!/usr/bin/perl

use strict;
use Getopt::Std;
use Log::Log4perl qw(get_logger :levels);
use IO::Socket;
use POSIX qw(WNOHANG);
use Data::UUID;
use Data::Dumper;

use lib '../utils/lib';
use MyDB;
use ParseConfig;

my %opts;
getopts( "c:", \%opts );

if ( !defined $opts{'c'} ) {
	usage();
	exit;
}

#----------------------------------------------------------------------
# Lets put the config values into a hash
#----------------------------------------------------------------------
my $config_file = $opts{'c'};
my ($stat, $err) = ParseConfig::colon($config_file);
if (!$stat) {
	print "$err\n";
	exit 1;
}

my $config_vars = $err;

my $log_file = $config_vars->{'log_file'};

#----------------------------------------------------------------------
# log4perl setup
#----------------------------------------------------------------------
my $layout = Log::Log4perl::Layout::PatternLayout->new("%d %p> %F{1}:%L %M - %m%n");

my $saserver_logger = get_logger('SaServer');
$saserver_logger->level($INFO);

my $appender_saserver = Log::Log4perl::Appender->new(
	"Log::Dispatch::File",
	filename => $log_file,
	mode     => "append",
);
$appender_saserver->layout($layout);
$saserver_logger->add_appender($appender_saserver);

#----------------------------------------------------------------------
# dbh handle
#----------------------------------------------------------------------
my $sa_db = $config_vars->{'db_alias_sa'};

$SIG = sub {
	while((my $pid = waitpid(-1, WNOHANG)) >0) {
		print "Reaped child $pid\n";
	}
};

my $general_port = $config_vars->{'general_listen_port'};
my $software_port = $config_vars->{'software_listen_port'};

my $sock = IO::Socket::INET->new( 
	Listen    => 20,
	LocalPort => $general_port,
	Timeout   => 60*1,
	Reuse     => 1
);
if(!$sock) {
	$saserver_logger->fatal("Can't create listening socket: $!\n");
	exit 1;
}

$saserver_logger->info("SA server starts up on port $general_port ...\n");

my ($stat, $err) = start_sw_process($sa_db, $software_port);
if ($stat eq "error") {
	print "$err\n";
	exit 1;
}

while(1) {
    next unless my $session = $sock->accept;
    defined (my $pid = fork) or die "Can't fork: $!\n";

	if($pid == 0) {
        my $peer_ip = $session->peerhost;
		my $peer_hostname  = gethostbyaddr($session->peeraddr,AF_INET) || $session->peerhost;
		my $port = $session->peerport;
        my $id = undef;

        my ($stat, $err) = get_dbh($sa_db);
        if($stat ne "ok") {
            close $session;
            exit 0;
        }
        my $dbh_sa = $err;

        $session->autoflush(1);

        #client connected to server
		print $session "connected\n";

        $session->recv($id, 32, 0);

        my ($stat, $err) = register_client($dbh_sa, $id, $peer_ip, $peer_hostname);
        print $session "$stat|$err\n";

        $dbh_sa->disconnect;
		close $session;
		exit 0;
	} else {
		print "Forking child $pid\n";
	}
}

close $sock;


#======================================================================
# subroutines
#======================================================================

sub get_uuid {
    my $ug    = new Data::UUID;
    my $uuid = $ug->create_str();

    $uuid =~ s/-//g;

    return $uuid;
}

sub get_dbh {
    my $db = shift;
    
    my ($stat, $err) = MyDB::getDBH($db);
    return ("error", $err) if(!$stat);
    return ("ok", $err);
}

sub register_client {
    my $dbh = shift;
    my $id = shift;
    my $ip = shift;
    my $hostname = shift;

    #get managed server information
    my $sql = "SELECT id FROM managed_server where id='$id'";
    my $sth = $dbh->prepare($sql)
        or return ("error", "Couldn't prepare statement: " . $dbh->errstr);
    $sth->execute()
        or return ("error", "Couldn't execute statement: " . $sth->errstr);

    my $req_data = $sth->fetchrow_hashref;
    if(!$req_data->{"id"}) {
        my $uuid = get_uuid();
        $sql = "INSERT INTO managed_server VALUES ('$uuid','$hostname','$ip','0',now())";
        $sth = $dbh->prepare($sql)
            or return ("error", "Couldn't prepare statement: " . $dbh->errstr);
        $sth->execute()
            or return ("error", "Couldn't execute statement: " . $sth->errstr);
        return ("registered", $uuid);
    } else {
        $sql = "UPDATE managed_server set update_time=now() where id='$id'";
        $sth = $dbh->prepare($sql)
            or return ("error", "Couldn't prepare statement: " . $dbh->errstr);
        $sth->execute()
            or return ("error", "Couldn't execute statement: " . $sth->errstr);
        return ("updated", "");
    }
}

sub start_sw_process {
    my $db = shift;
    my $port = shift;

	defined(my $pid = fork) or return("error", "Can't fork: $!");

    if($pid == 0) {
        my ($stat, $err) = get_dbh($db);
        exit 0 if($stat ne "ok");
        my $dbh = $err;

        while(1) {
            my $sql = "SELECT ssq.id as id,ssq.sw_name as software,ms.ip as ip FROM server_software_queue ssq LEFT JOIN managed_server ms on ssq.id=ms.id";
            my $sth = $dbh->prepare($sql) or exit 1;
            $sth->execute() or exit 1;

            while(my $ref = $sth->fetchrow_hashref) {
                if(open(IN, "../software_repo/" . $ref->{"software"})) {
                    my $sock = IO::Socket::INET->new( 
                        PeerAddr => $ref->{"ip"},
                        PeerPort => $port,
                        Proto    => 'tcp'
                    );
                    next if(!$sock);

                    print $sock $ref->{"software"} . "\n";

                    my $buf = <$sock>;
                    $buf =~ s/[\s ]+$//g;
                    if($buf eq "got file name") {
                        binmode(IN);
                        my @out = <IN>;
                        print $sock @out;

                        close IN;
                        close $sock;

                        my $sql = "DELETE FROM server_software_queue where id='" .$ref->{"id"}. "' AND sw_name='" .$ref->{"software"}. "'";
                        next unless my $sth = $dbh->prepare($sql);
                        next unless $sth->execute();

                        $sql = "INSERT INTO server_software VALUES ('" .$ref->{"id"}. "','" .$ref->{"software"}. "','0',now())";
                        next unless $sth = $dbh->prepare($sql);
                        next unless $sth->execute();
                    }
                }

                sleep(10);
            }
        }

        $dbh->disconnect;
		exit 0;
    }

    return ("ok", "Forking child $pid");
}

sub usage {

	print << "EOP";

    USAGE:
		$0 -c

		DESCRIPTION:

		This program starts SA server.

		OPTIONS:

		-c .. Config file.


		EXAMPLES:
			$0 -c ../conf/SaServer.conf

EOP
}
