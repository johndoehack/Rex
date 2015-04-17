#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::CMDB::YAML;

use strict;
use warnings;

# VERSION

use base qw(Rex::CMDB::Base);

use Rex::Commands -no => [qw/get/];
use Rex::Logger;
use YAML;
use Data::Dumper;
use Hash::Merge qw/merge/;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  $self->{merger} = Hash::Merge->new();

  if ( !defined $self->{merge_behavior} ) {
    $self->{merger}->specify_behavior(
      {
        SCALAR => {
          SCALAR => sub { $_[0] },
          ARRAY  => sub { $_[0] },
          HASH   => sub { $_[0] },
        },
        ARRAY => {
          SCALAR => sub { $_[0] },
          ARRAY  => sub { $_[0] },
          HASH   => sub { $_[0] },
        },
        HASH => {
          SCALAR => sub { $_[0] },
          ARRAY  => sub { $_[0] },
          HASH   => sub { Hash::Merge::_merge_hashes( $_[0], $_[1] ) },
        },
      },
      'REX_DEFAULT',
    ); # first found value always wins

    $self->{merger}->set_behavior('REX_DEFAULT');
  }
  else {
    if ( ref $self->{merge_behavior} eq 'HASH' ) {
      $self->{merger}
        ->specify_behavior( $self->{merge_behavior}, 'USER_DEFINED' );
      $self->{merger}->set_behavior('USER_DEFINED');
    }
    else {
      $self->{merger}->set_behavior( $self->{merge_behavior} );
    }
  }

  bless( $self, $proto );

  return $self;
}

sub get {
  my ( $self, $item, $server ) = @_;

  # first open $server.yml
  # second open $environment/$server.yml
  # third open $environment/default.yml
  # forth open default.yml

  my (@files);

  if ( !ref $self->{path} ) {
    my $env       = environment;
    my $yaml_path = $self->{path};
    @files = (
      "$yaml_path/$env/$server.yml", "$yaml_path/$env/default.yml",
      "$yaml_path/$server.yml",      "$yaml_path/default.yml"
    );
  }
  elsif ( ref $self->{path} eq "CODE" ) {
    @files = $self->{path}->();
  }
  elsif ( ref $self->{path} eq "ARRAY" ) {
    @files = @{ $self->{path} };
  }

  @files = map { $self->_parse_path($_) } @files;

  my $all = {};
  Rex::Logger::debug( Dumper( \@files ) );

  for my $file (@files) {
    Rex::Logger::debug("CMDB - Opening $file");
    if ( -f $file ) {

      #my $content = eval { local ( @ARGV, $/ ) = ($file); <>; };
      #$content .= "\n";    # for safety

      my $ref = YAML::LoadFile($file);

      $all = $self->{merger}->merge( $all, $ref );
    }
  }

  if ( !$item ) {
    return $all;
  }
  else {
    return $all->{$item};
  }

  Rex::Logger::debug("CMDB - no item ($item) found");

  return;
}

1;
