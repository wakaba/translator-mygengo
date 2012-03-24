package myGengo::Client::Warabe::App;
use strict;
use warnings;
use Warabe::App;
use Warabe::App::Role::JSON;
push our @ISA, qw(Warabe::App::Role::JSON Warabe::App);

sub requires_no_csrf ($) {
  my $self = shift;
  my $http = $self->http;

  my $origin = $http->get_request_header ('Origin');
  if (not defined $origin) {
    my $referer = $http->get_request_header ('Referer');
    if (defined $referer) {
      $origin = $1 if $referer =~ m{^([0-9a-z+.-]+://[^/]+)};
    }
  }

  $self->throw_error (400, reason_phrase => 'No Origin: or Referer:')
      unless $origin;

  my $url = $http->url->stringify;
  my $request_origin = 'null';
  $request_origin = $1 if $url =~ m{^([0-9a-z+.-]+://[^/]+)};
  $self->throw_error
      (400, reason_phrase => 'Origin is different from the server')
      unless $origin eq $request_origin;
} # requires_no_csrf

sub requires_mygengo_keys_from_auth ($) {
  my $self = shift;
  my $http = $self->http;
  if (($http->request_auth->{auth_scheme} // '') ne 'basic') {
    $http->set_status (401);
    $http->set_response_auth
        ('basic', realm => 'myGengo API key and private key');
    $self->send_plain_text (401);
    $self->throw;
  }
} # requires_mygengo_keys_from_auth

1;

