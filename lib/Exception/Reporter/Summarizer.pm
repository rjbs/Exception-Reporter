use strict;
use warnings;
package Exception::Reporter::Summarizer;
# ABSTRACT: a thing that summarizes dumpables for reporting

use Carp ();
use Scalar::Util ();

=head1 OVERVIEW

This class exists almost entirely to allow C<isa>-checking.  It provides a
C<new> method that returns a blessed, empty object.  Passing it any parameters
will cause an exception to be thrown.

A C<sanitize_filename> method is also provided, which turns a vaguely
filename-like string into a safer filename string.

=cut

sub new {
  my $class = shift;

  Carp::confess("$class constructor does not take any parameters") if @_;

  return bless {}, $class;
}

sub sanitize_filename {
  my ($self, $filename) = @_;

  # These don't need to be actually secure, since we won't use this for
  # opening any filehandles. -- rjbs, 2012-07-03
  $filename =~ s/\.+/./g;
  $filename =~ s/[^-a-zA-Z0-9]/-/g;
  return $filename;
}

sub register_reporter {
  my ($self, $reporter) = @_;

  Carp::confess("register_reporter called, but a reporter was already registered")
    if $self->{reporter};

  $self->{reporter} = $reporter;
  Scalar::Util::weaken($self->{reporter});
  return;
}

sub reporter { $_[0]->{reporter} }

sub dump {
  my ($self, $value, $arg) = @_;
  $self->reporter->dumper->dump($value, $arg);
}

1;
