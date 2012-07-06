use strict;
use warnings;
package Exception::Reporter::Dumper;

sub new {
  my $class = shift;

  Carp::confess("$class constructor does not take any parameters") if @_;

  return bless {}, $class;
}

sub dump {
  my $class = ref $_[0] || $_[0];
  Carp::confess("$class does not implement required Exception::Reporter::Dumper method 'dump'");
}

1;
