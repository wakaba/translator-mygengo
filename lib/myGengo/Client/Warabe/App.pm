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

sub mygengo_webservice ($) {
  my $self = shift;
  return $self->{mygengo_webservice} ||= do {
    require myGengo::Client::WebService::myGengo::Lite;
    myGengo::Client::WebService::myGengo::Lite->new;
  };
} # mygengo_webservice

sub throw_mygengo_error ($$) {
  my ($self, $res) = @_;
  require Data::Dumper;
  $self->http->set_status (400);
  $self->send_plain_text (Data::Dumper::Dumper ({
    error_message => $res->error_message,
    error_details => $res->error_details,
  }));
  $self->throw;
} # throw_mygengo_error

sub requires_mygengo_job_row ($$) {
  my ($self, $job_id) = @_;
  require myGengo::Client::MySQL;
  require Dongry::Database;
  my $db = Dongry::Database->load ('mygengo');
  my $job = $db->table ('job')->find ({id => $job_id});
  $self->throw_error (404, reason_phrase => 'Job not found') unless $job;
  return $job;
} # requires_mygengo_job_row

sub translator_repo ($) {
  my $self = shift;
  return $self->{translator_repo} ||= do {
    require myGengo::Client::TranslationRepository;
    myGengo::Client::TranslationRepository->new;
  };
} # translator_repo

1;

