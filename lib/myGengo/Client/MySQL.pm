package myGengo::Client::MySQL;
use strict;
use warnings;
use Dongry::Type::JSON;
use Dongry::Type::Time;

$Dongry::Database::Registry->{mygengo} = {
  sources => {
    default => {
      dsn => '',
    },
    master => {
      dsn => '',
      writable => 1,
    },
  },
  schema => {
    job => {
      primary_keys => ['id'],
      type => {
        source_body => 'text',
        target_body => 'text',
        data => 'json',
        data_updated => 'timestamp',
        comments => 'json',
        comments_updated => 'timestamp',
        feedback => 'json',
        feedback_updated => 'timestamp',
        job_created => 'timestamp',
        updated => 'timestamp',
        approved => 'timestamp',
      },
      default => {
        updated => sub { time },
      },
    }, # job
    customer_comment => {
      primary_keys => ['id'],
      type => {
        body => 'text',
        created => 'timestamp',
      },
      default => {
        created => sub { time },
      },
    }, # customer_comment
    job_approval => {
      primary_keys => ['id'],
      type => {
        comment_for_translator => 'text',
        comment_for_mygengo => 'text',
        created => 'timestamp',
      },
      default => {
        created => sub { time },
      },
    }, # job_approval
    job_rejection => {
      primary_keys => ['id'],
      type => {
        comment_for_translator => 'text',
        created => 'timestamp',
      },
      default => {
        created => sub { time },
      },
    }, # job_rejection
  },
  onconnect => sub {
    my ($self, %args) = @_;
    $self->set_tz ('+00:00', source_name => $args{source_name});
  },
}; # mygengo

use Path::Class;
use JSON::Functions::XS qw(file2perl);

my $config_f = file (__FILE__)->dir->parent->parent->parent
    ->subdir ('config', 'mysql')->file ('dsns.json');
my $dsns = file2perl $config_f;

for (keys %{$dsns->{dsns}}) {
  my $sources = $Dongry::Database::Registry->{$_}->{sources};
  $sources->{default}->{dsn} = $dsns->{dsns}->{$_};
  $sources->{master}->{dsn} = $dsns->{dsns}->{$_};
}

1;
