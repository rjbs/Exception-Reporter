package Exception::Reporter;
use Moose;
# ABSTRACT: a generic exception-reporting object

with 'Exception::Reporter::Role::Reporter';

my $INSTANCE;
sub instance { return $INSTANCE ||= $_[0]->new; }

1;
