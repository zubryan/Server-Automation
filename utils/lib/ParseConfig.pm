package ParseConfig;

#----------------------------------------------------------------------
# This library parses apart a file and puts it into a hash. Useful for
# parsing apart config files.
#
# sub colon(): parses apart a config file that is colon separated.
#----------------------------------------------------------------------

sub colon {

  my $config_file = shift;

  my %config_vars;

  open CONFIG, "< $config_file" or return (0, "Can't open $config_file : $!");

  while (<CONFIG>) {
    chomp;
    my $line = $_;
    
    # -- skip comments. skip blank lines.
    if ( $line =~ /^#/ ) {
	 next;
    }

    if ( $line =~ /^[\s\t]+$/ ) {
	 next;
    }

    if ( $line eq '') {
	 next;
    }

    my ($field, @values) = split(/:/, $line);

    # --- For the values, replace any colons that were removed.
    my $value;
    foreach (@values) {
      $value .= "$_:";
    }
    chop($value);

    if ($line =~ /:$/) {
      $value .= "$value:";
    }

    # --- Remove leading and trailing spaces. 
    $field = trim($field);
    $value = trim($value);

    $config_vars{$field} = $value;
  }
  
  close CONFIG;

  return (1, \%config_vars);

}

#----------------------------------------------------------------------
# chop off white space from a variable. both leading and trailing
#----------------------------------------------------------------------
sub trim {
  
  my $var = shift;
  
  $var =~ s/^[\s\t]*//;
  $var =~ s/[\s\t]*$//;

  return $var;
}
1;
