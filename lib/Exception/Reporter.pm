use strict;
use warnings;
package Exception::Reporter;
# ABSTRACT: a generic exception-reporting object

use Data::GUID guid_string => { -as => '_guid_string' };

sub new {
  my ($class, $arg) = @_;

  bless $arg => $class;
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
      # use Data::Dumper; warn Dumper($sum, $dumpable);
      next unless $sum->can_summarize($dumpable);
      warn "using $sum\n";
      push @summaries, $sum->summarize($dumpable);
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
