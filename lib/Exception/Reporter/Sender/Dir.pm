use strict;
use warnings;
package Exception::Reporter::Sender::Dir;
# ABSTRACT: a report sender that writes to directories on the filesystem

use parent 'Exception::Reporter::Sender';

=head1 SYNOPSIS

  my $sender = Exception::Reporter::Sender::Dir->new({
    root => '/var/error/my-app',
  });

=head1 OVERVIEW

This report sender writes reports to the file system.  Given a report with
bunch dumpable items, the Dir sender will make a directory and write each item
to a file in it, using the ident when practical, and a generated filename
otherwise.

=cut

use Digest::MD5 ();
use JSON ();
use Path::Tiny;
use String::Truncate;
use Try::Tiny;

sub new {
  my ($class, $arg) = @_;

  my $root = $arg->{root} || Carp::confess("missing 'root' argument");

  use Path::Tiny;

  $root = path($root);

  if (-e $root && ! -d $root) {
    Carp::confess("given root <$root> is not a writable directory");
  }

  $root->mkpath unless -e $root;

  return bless {
    root => $root,
  }, $class;
}

=head2 send_report

 $email_reporter->send_report(\@summaries, \%arg, \%internal_arg);

This method makes a subdirectory for the report and writes it out.

C<%arg> is the same set of arguments given to Exception::Reporter's
C<report_exception> method.  Arguments that will have an effect include:

  reporter     - the name of the program reporting the exception
  handled      - if true, the reported exception was handled and the user
                 saw a simple error message; sets X-Exception-Handled header
                 and adds a text part at the beginning of the report,
                 calling out the "handled" status"

C<%internal_arg> contains data produced by the Exception::Reporter using this
object.  It includes the C<guid> of the report and the C<caller> calling the
reporter.

The return value of C<send_report> is not defined.

=cut

my $JSON;

sub send_report {
  my ($self, $summaries, $arg, $internal_arg) = @_;

  # ?!? Presumably this can't really happen, but... you know what they say
  # about zero-summary incidents, right?  -- rjbs, 2012-07-03
  Carp::confess("can't report a zero-summary incident!") unless @$summaries;

  # We always use this file for internal use.
  my %manifest = ('report.json' => { description => 'report metadata' });
  my %report = (
    guid     => $internal_arg->{guid},
    manifest => \%manifest,
  );

  my $n = 1;

  my $safename = sub {
    my ($name) = @_;
    # Surely this is sub-optimal: -- rjbs, 2016-07-19
    $name =~ s{\.\.}{DOTDOT}g;
    $name =~ s{/}{BACKSLASH}g;
    $name =~ s{[^-_0-9a-z.]}{-}gi;

    my $base = $name;
    $name = "$base-" . $n++ while $manifest{$name};

    return $name;
  };

  my $root = $self->{root}->child($internal_arg->{guid});
  $root->mkpath;

  my @parts;
  GROUP: for my $summary (@$summaries) {
    my @these_parts;

    my $t_path = \&path;
    if (@{ $summary->[1] } > 1) {
      my $name = $safename->($summary->[0]);
      $manifest{$name} = { ident => $summary->[0] };

      $root->child($name)->mkpath;
      my $target_path = path($name);

      $t_path = sub { $target_path->child($_[0]) };
    }

    for my $inner (@{ $summary->[1] }) {
      my $file = $t_path->(
        $safename->( $inner->{filename} || 'inner' )
      );

      $manifest{$file} = {
        filename      => $inner->{filename},
        content_type  => $inner->{mimetype},

        (($inner->{body_is_bytes} && $inner->{charset})
          ? (charset => $inner->{charset})
          : ()),
      };

      my $method = $inner->{body_is_bytes} ? 'spew_raw' : 'spew_utf8';
      $root->child($file)->$method($inner->{body});
    }
  }

  if ($arg->{handled}) {
    $report{handled} = \1;
  }

  my ($package, $filename, $line) = @{ $internal_arg->{caller} };

  $report{reporter} = $arg->{reporter};
  $report{caller}   = "$filename line $line ($package)";

  $JSON ||= JSON->new->canonical->pretty;
  my $json = $JSON->encode(\%report);

  $root->child('report.json')->spew_utf8($json);

  return;
}

1;
