use strict;
use warnings;
package Exception::Reporter;
# ABSTRACT: a generic exception-reporting object

=head1 SYNOPSIS

B<Achtung!>  This is an experimental refactoring of some long-standing internal
code.  It might get even more refactored.  Once I've sent a few hundred
thousand exceptions through it, I'll remove this warning...

First, you create a reporter.  Probably you stick it someplace globally
accessible, like MyApp->reporter.

  my $reporter = Exception::Reporter->new({
    always_dump => { env => sub { \%ENV } },
    sender      => [
      Exception::Reporter::Sender::Email->new({
        from => 'root',
        to   => 'SysAdmins <sysadmins@example.com>',
      }),
    ],
    summarizers => [
      Exception::Reporter::Summarizer::Email->new,
      Exception::Reporter::Summarizer::File->new,
      Exception::Reporter::Summarizer::ExceptionClass->new,
      Exception::Reporter::Summarizer::Fallback->new,
    ],
  });

Later, some exception has been thrown!  Maybe it's an L<Exception::Class>-based
exception, or a string, or a L<Throwable> object or who knows what.

  try {
    ...
  } catch {
    MyApp->reporter->report_exception(
      [
        [ exception => $_ ],
        [ request   => $current_request ],
        [ uploading => Exception::Reporter::Dumpable::File->new($filename) ],
      ],
    );
  };

The sysadmins will get a nice email report with all the dumped data, and
reports will thread.  Awesome, right?

=head1 OVERVIEW

Exception::Reporter takes a bunch of input (the I<dumpables>) and tries to
figure out how to summarize them and build them into a report to send to
somebody.  Probably a human being.

It does this with two kinds of plugins:  summarizers and senders.

The summarizers' job is to convert each dumpable into a simple hashref
describing it.  The senders' job is to take those hashrefs and send them to
somebody who cares.

=cut

use Data::GUID guid_string => { -as => '_guid_string' };

=method new

  my $reporter = Exception::Reporter->new(\%arg);

This returns a new reporter.  Valid arguments are:

  summarizers  - an arrayref of summarizer objects; required
  senders      - an arrayref of sender objects; required
  always_dump  - a hashref of coderefs used to generate extra dumpables
  caller_level - if given, the reporter will look n frames up; see below

The C<always_dump> hashref bears a bit more explanation.  When
C<L</report_exception>> is called, each entry in C<always_dump> will be
evaluated and appended to the list of given dumpables.  This lets you make your
reporter always include some more useful information.

I<...but remember!>  The reporter is probably doing its job in a C<catch>
block, which means that anything that might have been changed C<local>-ly in
your C<try> block will I<not> be the same when evaluated as part of the
C<always_dump> code.  This might not matter often, but keep it in mind when
setting up your reporter.

In real code, you're likely to create one Exception::Reporter object and make
it globally accessible through some method.  That method adds a call frame, and
Exception::Reporter sometimes looks at C<caller> to get a default.  If you want
to skip those intermedite call frames, pass C<caller_level>.  It will be used
as the number of frames up the stack to look.  It defaults to zero.

=cut

sub new {
  my ($class, $arg) = @_;

  my $guts = {
    summarizers  => $arg->{summarizers},
    senders      => $arg->{senders},
    always_dump  => $arg->{always_dump},
    caller_level => $arg->{caller_level} || 0,
  };

  if ($guts->{always_dump}) {
    for my $key (keys %{ $guts->{always_dump} }) {
      Carp::confess("non-coderef entry in always_dump: $key")
        unless ref($guts->{always_dump}{$key}) eq 'CODE';
    }
  }

  for my $test (qw(Summarizer Sender)) {
    my $class = "Exception::Reporter::$test";
    my $key   = "\L${test}s";

    Carp::confess("no $key given!") unless $arg->{$key} and @{ $arg->{$key} };
    Carp::confess("entry in $key is not a $class")
      if grep { ! $_->isa($class) } @{ $arg->{$key} };
  }

  bless $guts => $class;
}

sub _summarizers { return @{ $_[0]->{summarizers} }; }
sub _senders     { return @{ $_[0]->{senders} }; }

=method report_exception

  $reporter->report_exception(\@dumpables, \%arg);

This method makes the reporter do its job: summarize dumpables and send a
report.

Useful options in C<%arg> are:

  reporter    - the program or authority doing the reporting; defaults to
                the calling package

  handled     - this indicates that this exception has been handled and that
                the user has not seen a terribel crash; senders might use
                this to decide who needs to get woken up

  extra_rcpts - this can be an arrayref of email addresses to be used as
                extra envelope recipients by the Email sender

Each entry in C<@dumpables> is expected to look like this:

  [ $short_name, $value, \%arg ]

The short name is used for a few things, including identifying the dumps inside
the report produced.  It's okay to have duplicated short names.

The value can, in theory, be I<anything>.  It can be C<undef>, any kind of
object, or whatever you want to stick in a scalar.  It's possible that
extremely exotic values could confuse the "fallback" summarizer of last resort,
but for the most part, anything goes.

The C<%arg> entry isn't used for anything by the core libraries that ship with
Exception::Reporter, but you might want to use it for your own purposes.  Feel
free.

The reporter will try to summarize each dumpable by asking each summarizer, in
order, whether it C<can_summarize> the dumpable.  If it can, it will be asked
to C<summarize> the dumpable.  The summaries are collected into a structure
that looks like this:

  [
    [ dumpable_short_name => \@summaries ],
    ...
  ]

If a given dumpable can't be dumped by any summarizer, a not-very-useful
placeholder is put in its place.

The arrayref constructed is passed to the C<send_report> method of each sender,
in turn.

=cut

sub report_exception {
  my ($self, $dumpables, $arg) = @_;
  $dumpables ||= [];
  $arg ||= {};

  my $guid = _guid_string;

  my @caller = caller( $self->{caller_level} );
  $arg->{reporter} ||= $caller[0];

  my @summaries;

  my @sumz = $self->_summarizers;

  DUMPABLE: for my $dumpable (
    @$dumpables,
    map {; [ $_, $self->{always_dump}{$_}->() ] }
      sort keys %{$self->{always_dump}}
  ) {
    for my $sum (@sumz) {
      next unless $sum->can_summarize($dumpable);
      push @summaries, [ $dumpable->[0], [ $sum->summarize($dumpable) ] ];
      next DUMPABLE;
    }

    push @summaries, [
      $dumpable->[0],
      [ {
        ident => "UNKNOWN",
        body  => "the entry for <$dumpable->[0]> could not be summarized",
        mimetype => 'text/plain',
        filename => 'unknown.txt',
      } ],
    ];
  }

  for my $sender ($self->_senders) {
    $sender->send_report(
      \@summaries,
      $arg,
      {
        guid   => $guid,
        caller => \@caller,
      }
    );
  }

  return $guid;
}

1;
