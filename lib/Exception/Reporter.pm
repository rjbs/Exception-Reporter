use strict;
use warnings;
package Exception::Reporter;
# ABSTRACT: a generic exception-reporting object

use Data::GUID guid_string => { -as => '_guid_string' };

sub new {
  my ($class, $arg) = @_;

  my $guts = {
    summarizers => $arg->{summarizers},
    reporters   => $arg->{reporters},
    always_dump => $arg->{always_dump},
  };

  if ($guts->{always_dump}) {
    for my $key (keys %{ $guts->{always_dump} }) {
      Carp::confess("non-coderef entry in always_dump: $key")
        unless ref($guts->{always_dump}{$key}) eq 'CODE';
    }
  }

  for my $test (qw(Summarizer Reporter)) {
    my $class = "Exception::Reporter::$test";
    my $key   = "\L${test}s";

    Carp::confess("no $key given!") unless $arg->{$key} and @{ $arg->{$key} };
    Carp::confess("entry in $key is not a $class")
      if grep { ! $_->isa($class) } @{ $arg->{$key} };
  }

  bless $guts => $class;
}

sub _summarizers { return @{ $_[0]->{summarizers} }; }
sub _reporters   { return @{ $_[0]->{reporters} }; }

sub report_exception {
  my ($self, $dumpables, $arg) = @_;
  $dumpables ||= [];
  $arg ||= {};

  my $guid = _guid_string;

  my @summaries;

  my @sumz = $self->_summarizers;

  for my $dumpable (
    @$dumpables,
    map {; [ $_, $self->{always_dump}{$_}->() ] }
      sort keys %{$self->{always_dump}}
  ) {
    SUMMARIZER: for my $sum (@sumz) {
      next unless $sum->can_summarize($dumpable);
      push @summaries, [ $dumpable->[0], [ $sum->summarize($dumpable) ] ];
      last SUMMARIZER;
    }
  }

  for my $reporter ($self->_reporters) {
    $reporter->send_report(
      \@summaries,
      $arg,
      {
        guid   => $guid,
        caller => [caller],
      }
    );
  }

  return $guid;
}

1;
