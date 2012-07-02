package Exception::Reporter::Role::Dispatcher;
use Moose::Role;

use Data::GUID qw(guid_string);
use List::Util qw(first);
use Params::Util qw(_HASH0);
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

  $summary->{guid}    ||= guid_string;
  $summary->{to_dump} ||= {};

  $_->summarize($error, $summary) for $invocant->summarizers;

  $summary->{reporter} ||= caller;

  for my $key (keys %{ $summary->{to_dump} }) {
    $summary->{to_dump} = [ data => $summary->{to_dump}{$key} ]
      if _HASH0($summary->{to_dump}{$key});
  }

  $summary->{to_dump} ||= [ data => \%ENV ];

  # {
  #   handled   => $bool,
  #   reporter  => $name,
  #   ident     => $ident,
  #   message   => $msg,
  #   fulltext  => $text,
  #   stack     => $stack, # make this just a to_dump ?
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
  builder => 'default_summarizers',
  handles => {
    summarizers     => 'elements',
    _add_summarizer => 'push',
  },
);

has reporters => (
  is  => 'ro',
  isa => 'ArrayRef[Exception::Reporter::Role::Reporters]',
  traits  => 'Array',
  builder => 'default_reporters',
  handles => {
    reporters => 'elements',
  },
);

1;
