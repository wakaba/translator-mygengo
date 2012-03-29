package myGengo::Client::TranslationRepository;
use strict;
use warnings;
use URL::PercentEncode qw(percent_encode_c);

my $Config;

sub new ($) {
  my $class = shift;
  return bless {}, $class;
} # new

sub get_msg_update_url_as_string ($) {
  return $Config->{msg_update_url} or die "msg_update_url not configured";
} # get_msg_update_url_as_string

sub get_msg_permalink_url_as_string ($%) {
  my (undef, %args) = @_;
  return undef unless $args{msgid};
  return undef unless @{$args{langs} || []};
  my $url = $Config->{msg_permalink_url}
      or die "msg_permalink_url not configured";
  $url =~ s[\{langs\}]
           [join ',', map { percent_encode_c $_ } @{$args{langs}}]ge;
  $url =~ s[\{msgid\}][percent_encode_c $args{msgid}]ge;
  return $url;
} # get_msg_permalink_url_as_string

use Path::Class;
use JSON::Functions::XS qw(file2perl);

my $config_file_name = $ENV{MYGENGO_CLIENT_TRANSLATION_REPOSITORY_JSON}
    || 'config/translator/repo.json';

my $config_f = file ($config_file_name)
    ->absolute(file (__FILE__)->dir->parent->parent->parent);
$Config = file2perl $config_f;

1;
