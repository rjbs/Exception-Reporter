#!perl
use strict;
use warnings;

local $ENV{EMAIL_SENDMAIL_MAILER} = 'Test';

use Email::MIME;
use ICG::Exceptions;
use ICG::Sendmail2;
use YAML::Syck qw(Load);

use Test::More tests => 45;

BEGIN { use_ok('ICG::Mason'); }

{ # simple test
  ICG::Sendmail2->clear_mailer;

  my $uuid = ICG::Mason->report_exception(
    'test exception at t/mason-exception.t line 17',
    { foo => 'bar', pants => [ qw(on off on off on off) ] },
  );

  my @messages = ICG::Sendmail2->mailer->deliveries;

  is(@messages, 1, "we've sent one message");

  my $email = Email::MIME->new($messages[0]{email}->as_string);

  is(
    $email->header('subject'),
    'ICG::Mason: test exception',
    "the subject correctly stripped trace data",
  );

  like(
    $email->header('message-id'),
    qr/<$uuid\@\S+>/,
    "message id uses the returned uuid as the local part",
  );

  like($email->header('content-type'), qr{multipart/mixed}i, "it's multipart");

  my ($summary, @parts) = $email->parts;

  is(@parts, 3, "there are two attachments beyond the summary: one per dump");

  # The ordering below works because dumpables are dumped alphabetically.
  is_deeply(
    Load($parts[0]->body),
    \%ENV,
    "the first dump is the environment",
  );

  is_deeply(
    Load($parts[1]->body),
    'bar',
    'first part contains expected dump',
  );

  is_deeply(
    Load($parts[2]->body),
    [ qw(on off on off on off) ],
    'second part contains expected dump',
  );

  is(
    $email->header('in-reply-to'),
    '<a93af8c2ed1e5ff3e90cac02a5ad3d7d@ICG::Mason>',
    "correct in-reply-to header"
  );

  is($email->header('x-mailer'), 'ICG::Exceptions', 'correct x-mailer');
}

{ # simple test with object
  my $exception = X::BadValue->new('test exception');

  ICG::Sendmail2->clear_mailer;

  my $uuid = ICG::Mason->report_exception(
    $exception,
    { foo => 'bar', pants => [ qw(on off on off on off) ] },
  );

  my @messages = ICG::Sendmail2->mailer->deliveries;

  is(@messages, 1, "we've sent one message");

  my $email = Email::MIME->new($messages[0]{email}->as_string);

  is(
    $email->header('subject'),
    'ICG::Mason: invalid value: test exception',
    "the subject correctly stripped trace data",
  );

  like(
    $email->header('message-id'),
    qr/<$uuid\@\S+>/,
    "message id uses the returned uuid as the local part",
  );

  like($email->header('content-type'), qr{multipart/mixed}i, "it's multipart");

  my ($summary, @parts) = $email->parts;

  is(@parts, 3, "there are two attachments beyond the summary: one per dump");

  # The ordering below works because dumpables are dumped alphabetically.
  is_deeply(
    Load($parts[0]->body),
    \%ENV,
    "the first dump is the environment",
  );

  is_deeply(
    Load($parts[1]->body),
    'bar',
    'first part contains expected dump',
  );

  is_deeply(
    Load($parts[2]->body),
    [ qw(on off on off on off) ],
    'second part contains expected dump',
  );

  is(
    $email->header('in-reply-to'),
    '<4b3f0902eebf5f4279350b82a30beb2b@ICG::Mason>',
    "correct in-reply-to header"
  );

  is($email->header('x-mailer'), 'ICG::Exceptions', 'correct x-mailer');

  ok(!$email->header('x-icg-exception-handled'), "it was not 'handled'");
}

{ # simple test with object, handled
  my $exception = X::BadValue->new('test exception');

  ICG::Sendmail2->clear_mailer;

  my $uuid = ICG::Mason->report_exception(
    $exception,
    { foo => 'bar', pants => [ qw(on off on off on off) ] },
    { handled => 1 },
  );

  my @messages = ICG::Sendmail2->mailer->deliveries;

  is(@messages, 1, "we've sent one message");

  my $email = Email::MIME->new($messages[0]{email}->as_string);

  my ($prelude, $summary, @parts) = $email->parts;

  is(@parts, 3, "2 dumpables + environment = 3 parts (plus summary, prelude)");

  like(
    $prelude->body,
    qr{DON'T PANIC},
    "there is a big fronter saying DON'T PANIC",
  );

  ok($email->header('x-icg-exception-handled'), "it was 'handled'");
}

{ # simple test with mason exception
  require HTML::Mason::Exceptions;
  my $exception = HTML::Mason::Exception->new(error => 'test exception');

  ICG::Sendmail2->clear_mailer;

  my $uuid = ICG::Mason->report_exception(
    $exception,
    { foo => 'bar', pants => [ qw(on off on off on off) ] },
  );

  my @messages = ICG::Sendmail2->mailer->deliveries;

  is(@messages, 1, "we've sent one message");

  my $email = Email::MIME->new($messages[0]{email}->as_string);

  is(
    $email->header('subject'),
    'ICG::Mason: generic base class for all Mason exceptions: test ...',
    "the subject correctly stripped trace data",
  );

  like(
    $email->header('message-id'),
    qr/<$uuid\@\S+>/,
    "message id uses the returned uuid as the local part",
  );

  like($email->header('content-type'), qr{multipart/mixed}i, "it's multipart");

  my ($summary, @parts) = $email->parts;

  is(@parts, 3, "there are two attachments beyond the summary: one per dump");

  # The ordering below works because dumpables are dumped alphabetically.
  is_deeply(
    Load($parts[0]->body),
    \%ENV,
    "the first dump is the environment",
  );

  is_deeply(
    Load($parts[1]->body),
    'bar',
    'first part contains expected dump',
  );

  is_deeply(
    Load($parts[2]->body),
    [ qw(on off on off on off) ],
    'second part contains expected dump',
  );

  is(
    $email->header('in-reply-to'),
    '<db8a9eb6972341492fccd8cc54795088@ICG::Mason>',
    "correct in-reply-to header"
  );

  is($email->header('x-mailer'), 'ICG::Exceptions', 'correct x-mailer');
}

{ # attachment test
  ICG::Sendmail2->clear_mailer;

  my $uuid = ICG::Mason->report_exception(
    'test exception at t/mason-exception.t line 17',
    { foo => 'bar', pants => [ qw(on off on off on off) ] },
    {
      attach_files => [
        {
          content_type => 'text/passwd',
          filename     => '/etc/passwd',
        },
      ],
    }
  );

  my @messages = ICG::Sendmail2->mailer->deliveries;

  is(@messages, 1, "we've sent one message");

  my $email = Email::MIME->new($messages[0]{email}->as_string);

  is(
    $email->header('subject'),
    'ICG::Mason: test exception',
    "the subject correctly stripped trace data",
  );

  like(
    $email->header('message-id'),
    qr/<$uuid\@\S+>/,
    "message id uses the returned uuid as the local part",
  );

  like($email->header('content-type'), qr{multipart/mixed}i, "it's multipart");

  my ($summary, @parts) = $email->parts;

  is(
    @parts,
    4,
    "4 parts = summary + 2 dumps + 1 attachment",
  );

  # The ordering below works because dumpables are dumped alphabetically.
  is_deeply(
    Load($parts[0]->body),
    \%ENV,
    "the first dump is the environment",
  );

  is_deeply(
    Load($parts[1]->body),
    'bar',
    'first part contains expected dump',
  );

  is_deeply(
    Load($parts[2]->body),
    [ qw(on off on off on off) ],
    'second part contains expected dump',
  );


  like(
    $parts[3]->body,
    qr{^root:[^:]+?:0},
    'attached part contains passwd line',
  );
}
