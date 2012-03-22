#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
BEGIN {
  my $file_name = dirname (__FILE__) . '/../config/perl/libs.txt';
  open my $file, '<', $file_name or die "$0: $file_name: $!";
  unshift @INC, split /:/, scalar <$file>;
}
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->subdir ('modules', '*', 'lib')->stringify;
use Wanage::HTTP;
use Warabe::App;
use myGengo::Client::Web;

sub {
  my $http = Wanage::HTTP->new_from_psgi_env ($_[0]);
  my $app = Warabe::App->new_from_http ($http);

  $app->execute (sub {
    myGengo::Client::Web->process ($app);
  });
  return $http->send_response;
};
