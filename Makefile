PERL = perl
PERL_VERSION = latest
PERL_PATH = $(abspath local/perlbrew/perls/perl-$(PERL_VERSION)/bin)
PROVE = prove

all:

## ------ Deps ------

Makefile-setupenv: Makefile.setupenv
	make --makefile Makefile.setupenv setupenv-update \
	    SETUPENV_MIN_REVISION=20120318

Makefile.setupenv:
	wget -O $@ https://raw.github.com/wakaba/perl-setupenv/master/Makefile.setupenv

remotedev-test remotedev-reset remotedev-reset-setupenv \
config/perl/libs.txt local-perl generatepm \
perl-exec perl-version \
carton-install carton-update carton-install-module \
local-submodules: %: Makefile-setupenv
	make --makefile Makefile.setupenv $@

## ------ Tests ------

PERL_ENV = PATH=$(PERL_PATH):$(PATH) PERL5LIB=$(shell cat config/perl/libs.txt)

test: safetest

safetest: carton-install config/perl/libs.txt \
    testdb-start safetest-main testdb-stop

PREPARE_DB_SET = modules/perl-rdb-utils/bin/prepare-db-set.pl
PREPARE_DB_SET_ = $(PERL) $(PREPARE_DB_SET)

testdb-start:
	mkdir -p config/mysql
	$(PERL_ENV) $(PREPARE_DB_SET_) \
	    --preparation-file-name db/preparation.txt \
	    --dsn-list config/mysql/dsns.json

testdb-stop:
	$(PERL_ENV) $(PREPARE_DB_SET_) \
	    --stop \
	    --dsn-list config/mysql/dsns.json

safetest-main: 
	$(PERL_ENV) $(PROVE) t/*.t

always:

## License: Public Domain.
