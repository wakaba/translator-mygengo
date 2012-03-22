package myGengo::Client::Web;
use strict;
use warnings;

sub process ($$) {
  my $app = $_[1];
  my $http = $app->http;
  
  my $path = $app->path_segments;
  if (@$path == 1 and $path->[0] eq 'syncjobs') {
    if (($http->request_auth->{auth_scheme} // '') ne 'basic') {
      $http->set_status (401);
      $http->set_response_auth
          ('basic', realm => 'myGengo API key and private key');
      $app->send_plain_text (401);
      $app->throw;
    }

    require myGengo::Client::MySQL;
    require Dongry::Database;
    require WebService::myGengo::Lite;
    
    my $ws = WebService::myGengo::Lite->new
        (api_key => $http->request_auth->{userid},
         private_key => $http->request_auth->{password});

    my $res = $ws->job_list;
    $app->throw_error (400) if $res->is_error;

    $res = $ws->jobs_get ([map { $_->{job_id} } @{$res->data}]);
    $app->throw_error (400) if $res->is_error;

    my $db = Dongry::Database->load ('mygengo');

    for my $job (@{$res->jobs}) {
      $db->table ('job')->insert ([{
        id => $job->{job_id},
        source_lang => $job->{source}->{lang} // '',
        source_body => $job->{source}->{body} // '',
        target_lang => $job->{target}->{lang} // '',
        target_body => $job->{target}->{body} // '',
        status => $job->{status},
        data => {%$job},
        updated => time,
      }], duplicate => 'replace');
    }
    
    $app->send_plain_text ('done');
  } else {
    $app->throw_error (404);
  }
} # process

1;
