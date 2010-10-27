package Exception::Reporter::Summarizer::Fallback;
use Moose;
with 'Exception::Reporter::Role::Summarizer';

sub summarize {
  my ($self, $error, $summary) = @_;

  unless (defined $summary->{fulltext} and $summary->{fulltext} =~ /\S/) {
    $summary->{fulltext} = try   { "$error" }
                           catch { "error summarizing exception!" };
  }

  unless ($summary->{ident}) {
    my $string = $summary->{fulltext};

    $string =~ s/\A\s+//sm;
    my ($ident) = split /\n/, $string, 2;
    $ident = "unidentifiable error)" unless defined $ident and $ident =~ /\S/;

    $summary->{ident} = $ident;
  }

  $summary->{message} = $ident unless defined $summary->{message};

  $ident =~ s/\s+(?:at .+?)? ?line\s\d+\.?$//;

  return;
}

1;
