use strict;
use warnings;
package Exception::Reporter::Summarizer;
# ABSTRACT: a thing that summarizes dumpables for reporting

use Carp ();

=head1 OVERVIEW

This class exists almost entirely to allow C<isa>-checking.  It provides a
C<new> method that returns a blessed, empty object.  Passing it any parameters
will cause an exception to be thrown.

A C<sanitize_filename> method is also provided, which turns a vaguely
filename-like string into a safer filename string.

=cut

sub new {
  my ($class, $arg) = @_;

  return bless {}, $class;
}

sub sanitize_filename {
  my ($self, $filename) = @_;

  $filename =~ s/[^-a-zA-Z0-9]/-/g;
  return $filename;
}

1;
