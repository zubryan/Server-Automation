package MyDB;
use strict;
use DBI;

#----------------------------------------------------------------------
#
# This is a general use library to connect to various databases.
# To add a new database connection to this library, create a new
# subroutine, following the ikb() example.
#
# There is no need to modify getDBH(). These are the following
# attributes that are pre-defined:
#
#  PrintError => 0,
#  RaiseError => 0,
#  AutoCommit => 1
#                                 
# If you wish to change these attributes, you can do so once you
# receive the database handle (ie:  $h->{AutoCommit} = ...; )
#
# To call this library, call getDBH() and pass in the db name.
#
#----------------------------------------------------------------------

sub getDBH {

#----------------------------------------------------------------------
# Inputs
#----------------------------------------------------------------------
	my $db_name  = shift;

	if (!defined $db_name) {
		return (0, "Database name not defined.");
	}

#----------------------------------------------------------------------
# to get around strict refs, create table
#----------------------------------------------------------------------
	my %db_table = (
			$db_name  => \&{$db_name},
			);

	my $db_info;
	eval {
		$db_info = $db_table{$db_name}->();
	};

	if ($@) {
		return (0, "Please check database name: $@");
	}

#----------------------------------------------------------------------
# db connect
#----------------------------------------------------------------------
	my $data_source = $db_info->{ 'data_source' };
	my $username    = $db_info->{ 'username'    };
	my $auth        = $db_info->{ 'password'    };

	my $dbh;
	eval {
		$dbh = DBI->connect(
            $data_source,
			$username,
			$auth,
			{
			    PrintError => 0,
				RaiseError => 0,
				AutoCommit => 1
			}
		);
	};

	if (!defined $dbh) {
		return (0, "Error connecting to database: " . DBI->errstr);
	}

	return (1, $dbh);

}

#----------------------------------------------------------------------
# DB Info for sa
#----------------------------------------------------------------------
sub sa {

	my %db_info = (		
		data_source => 'DBI:mysql:database=sa;host=localhost',
		username    => 'root',
		password    => 'whoami',
	);

	return (\%db_info);
}

1;
