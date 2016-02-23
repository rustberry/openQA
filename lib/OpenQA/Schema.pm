# Copyright (C) 2014-2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package OpenQA::Schema;
use parent qw/DBIx::Class::Schema/;
use strict;
use warnings;

use DBIx::Class::DeploymentHandler;
use Config::IniFiles;
use Cwd qw/abs_path/;
use Try::Tiny;
use FindBin qw/$Bin/;

# after bumping the version please look at the instructions in the docs/Contributing.asciidoc file
# on what scripts should be run and how
our $VERSION   = 36;
our @databases = qw/MySQL SQLite PostgreSQL/;

__PACKAGE__->load_namespaces;

sub connect_db {
    my $mode = shift || $ENV{OPENQA_DATABASE} || 'production';
    my $prepare_mode;
    if ($mode eq 'prepare_production') {
        $prepare_mode = 1;
        $mode         = 'production';
    }
    CORE::state $schema;
    unless ($schema) {
        my %ini;
        my $cfgpath = $ENV{OPENQA_CONFIG} || "$Bin/../etc/openqa";
        tie %ini, 'Config::IniFiles', (-file => $cfgpath . '/database.ini');
        $schema = __PACKAGE__->connect($ini{$mode});

        if (!$prepare_mode) {
            deployment_check($schema);
        }
    }
    return $schema;
}

sub dsn {
    my $self = shift;
    $self->storage->connect_info->[0]->{dsn};
}

sub deployment_check {
    my ($schema) = @_;
    my $dir = $FindBin::Bin;
    while (abs_path($dir) ne '/') {
        last if (-d "$dir/dbicdh");
        $dir = "$dir/..";
    }
    $dir = "$dir/dbicdh";
    die 'Cannot find database schema files' if (!-d $dir);

    my $dh = DBIx::Class::DeploymentHandler->new(
        {
            schema              => $schema,
            script_directory    => $dir,
            databases           => \@databases,
            sql_translator_args => {add_drop_table => 0},
            force_overwrite     => 0
        });
    _try_deploy_db($dh) or _try_upgrade_db($dh);
}

sub _db_tweaks {
    my ($schema, $tweak) = @_;
    $schema->storage->dbh_do(
        sub {
            my ($storage, $dbh, @args) = @_;
            $dbh->do($tweak);
        });
}

sub _try_deploy_db {
    my ($dh) = @_;
    my $schema = $dh->schema;
    umask 027;
    my $version;
    try {
        $version = $dh->version_storage->database_version;
    }
    catch {
        if ($schema->dsn =~ /:SQLite:dbname=(.*)/) {
            # speed this up a bit
            _db_tweaks($schema, 'PRAGMA synchronous = OFF;');
        }
        $dh->install;
    };
    return !$version;
}

sub _try_upgrade_db {
    my ($dh) = @_;
    my $schema = $dh->schema;
    if ($dh->schema_version > $dh->version_storage->database_version) {
        if ($schema->dsn =~ /:SQLite:dbname=(.*)/) {
            # Some SQLite update scripts do not work correctly with foreign keys on
            _db_tweaks($schema, 'PRAGMA foreign_keys = OFF;');
        }
        $dh->upgrade;
        return 1;
    }
    return;
}

1;
# vim: set sw=4 et:
