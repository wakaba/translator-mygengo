package myGengo::Client::WebService::myGengo::Lite;
use strict;
use warnings;
use WebService::myGengo::Lite;
push our @ISA, qw(WebService::myGengo::Lite);

use Path::Class;
use JSON::Functions::XS qw(file2perl);

my $config_file_name = $ENV{MYGENGO_CLIENT_MYGENGO_ACCOUNT_JSON}
    || 'config/mygengo/account.json';

my $config_f = file (__FILE__)->dir->parent->parent->parent->parent->parent
    ->file ($config_file_name);
my $Config = file2perl $config_f;

sub api_key ($;$) {
  return $Config->{api_key};
} # api_key

sub private_key ($;$) {
  return $Config->{private_key};
} # private_key

sub is_production ($;$) {
  return $Config->{is_production};
} # is_production

sub callback_url ($;$) {
  return $Config->{callback_url};
} # callback_url

1;

