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
    },
  },
};

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
