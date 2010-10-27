package Exception::Reporter::Role::Dispatcher;
use Moose::Role;

use Data::GUID qw(guid_string);
use List::Util qw(first);
use Try::Tiny;

use Exception::Reporter::Types;

use namespace::autoclean;

sub report_exception {
  my ($invocant, $error, $summary) = @_;

  if (! blessed $invocant and $invocant->does('Exception::Role::Singleton')) {
    $invocant = $invocant->instance;
  }

  confess "report_exception must be called on an instance, not a class"
    unless blessed $invocant;

  $summary->{guid} ||= guid_string;

  $_->summarize($error, $summary) for $invocant->summarizers;

  # {
  #   handled   => $bool,
  #   reporter  => $name,
  #   ident     => $ident,
  #   message   => $msg,
  #   stack     => $stack,
  #   to_dump   => {
  #     key => { ...dumpable... },
  #     key => [ type => { ...dumpable... } ],
  #   },
  # }
  #
  # "type" may be attachment

  for my $reporter ($invocant->reporters) {
    try {
      $reporter->send_exception_report($error, $summary);
    } catch {
      # XXX: This could be better. -- rjbs, 2010-10-26
      warn "could not report exception $summary->{guid} to $reporter";
    }
  }
        
  return $summary->{guid};
}

has summarizers => (
  is  => 'ro',
  isa => 'ArrayRef[Exception::Reporter::Role::Summarizer]',
  traits  => 'Array',
  handles => {
    summarizers     => 'elements',
    _add_summarizer => 'push',
  },
);

has reporters => (
  is  => 'ro',
  isa => 'ArrayRef[Exception::Reporter::Role::Reporters]',
  traits  => 'Array',
  handles => {
    reporters => 'elements',
  },
);

1;
