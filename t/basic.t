use strict;
use warnings;

use lib 'lib';

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test'; }

use Test::More;

use Exception::Reporter;
use Exception::Reporter::Dumpable::File;
use Exception::Reporter::Reporter::Email;
use Exception::Reporter::Summarizer::Email;
use Exception::Reporter::Summarizer::File;
use Exception::Reporter::Summarizer::ExceptionClass;
use Exception::Reporter::Summarizer::Fallback;

use Exception::Class::Base;

my $reporter = Exception::Reporter->new({
  reporters   => [
    Exception::Reporter::Reporter::Email->new({
      from => 'root',
      to   => 'IC Group Sysadmins <sysadmins@icgroup.com>',
    }),
  ],
  summarizers => [
    Exception::Reporter::Summarizer::Email->new,
    Exception::Reporter::Summarizer::File->new,
    Exception::Reporter::Summarizer::ExceptionClass->new,
    Exception::Reporter::Summarizer::Fallback->new,
  ],
});

package X { sub x { Z->z } }
package Z { sub z {
  Exception::Class::Base->new(error => "Everything sucks.");
} }

my $exception = X->x;

my $email = Email::MIME->create(
  header     => [
    From    => 'rjbs@cpan.org',
    To      => 'perl5-porters@perl.org',
    Subject => 'I QUIT',
  ],
  attributes => {
    charset  => 'utf-8',
    encoding => 'quoted-printable',
    content_type => 'text/plain',
  },
  body_str   => "This was a triumph.\n",
);

my $file_1 = Exception::Reporter::Dumpable::File->new('live-demo.t');
my $file_2 = Exception::Reporter::Dumpable::File->new('does-not-exist.txt');

my $guid = $reporter->report_exception(
  [
    [ ecb    => $exception  ],
    [ string => "Your mom." ],
    [ email  => $email      ],
    [ f1     => $file_1     ],
    [ f2     => $file_2     ],
  ],
  {
    handled  => 1,
    reporter => 'Xyz',
  },
);

{
  my @deliveries = Email::Sender::Simple->default_transport->deliveries;

  is(@deliveries, 1, "one delivery");

  my $delivery = $deliveries[0];
  my $email    = $delivery->{email};
  my $mime     = Email::MIME->new($email->as_string);
  my @parts    = $mime->subparts;

  like($mime->header('Message-Id'), qr/\A<\Q$guid\E\@/, "guid in msg-id");

  is(@parts, 8, "got eight parts");
}

done_testing;
