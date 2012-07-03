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
  };

  bless $guts => $class;
}

sub _summarizers {
  my ($self) = @_;
  return @{ $self->{summarizers} };
}

sub _reporters {
  my ($self) = @_;
  return @{ $self->{reporters} };
}

sub report_exception {
  my ($self, $dumpables, $arg) = @_;
  $dumpables ||= [];
  $arg ||= {};

  my $guid = _guid_string;

  my @summaries;

  my @sumz = $self->_summarizers;

  for my $dumpable (@$dumpables) {
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
