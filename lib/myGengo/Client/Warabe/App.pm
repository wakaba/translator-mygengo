package myGengo::Client::Warabe::App;
use strict;
use warnings;
use Warabe::App;
use Warabe::App::Role::JSON;
push our @ISA, qw(Warabe::App::Role::JSON Warabe::App);

1;

