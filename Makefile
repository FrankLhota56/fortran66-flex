PACKAGE ?= fortran66.tgz
FLEX_LIBDIR ?= /usr/local/opt/flex/lib

BISON_OPTS := --defines --output=y.tab.c
FLEX_OPTS := --case-insensitive

COMPAT ?= none
ifeq ($(COMPAT),lex)
	BISON_OPTS := --defines --yacc
	FLEX_OPTS := --case-insensitive --lex-compat
endif
ifeq ($(COMPAT),posix)
	BISON_OPTS := --defines --yacc
	FLEX_OPTS := --case-insensitive --posix-compat
endif

f66dump: f66dump.o lex.yy.o getcard.o
	$(CC) -o $@ $^ -L$(FLEX_LIBDIR) -lfl -lm
f66dump.o: f66dump.c field_desc.h y.tab.h

lex.yy.o: lex.yy.c getcard.h y.tab.h
lex.yy.c: fortran66.l
	flex $(FLEX_OPTS) $<

getcard.o: getcard.c getcard.h

y.tab.o: y.tab.c field_desc.h y.tab.h
y.tab.h: fortran66.y
	bison $(BISON_OPTS) $<
y.tab.c: y.tab.h

.PHONY: test
test: f66dump ## Tests grammar using f66dump and test cases.
	cd test; \
	$(RM) -r actual; \
	mkdir actual; \
	for F in *.for; do \
	   echo "Parsing $$F..."; \
	   ../f66dump $$F > actual/$${F/%.for/.out} 2> actual/$${F/%.for/.err}; \
	done; \
	diff -r actual expected

.PHONY: debug
debug: ## Builds grammar and f66dump in debug mode.
	flex --debug $(FLEX_OPTS) fortran66.l
	$(MAKE) f66dump

.PHONY: clean
clean: ## Removes all generated files.
	$(RM) *.o f66dump y.tab.[hc] lex.yy.c
	$(RM) -r test/actual

.PHONY: package
package: clean	## Packages sources into a gzip tar file.
	tar --create --verbose --gzip --file="$(PACKAGE)" $$(find * -type f \! -name "$(PACKAGE)")

.PHONY: help
help: ## Print out a list of available build targets.
	@echo "Make targets:"
	@echo
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-8s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Variables:"
	@echo "- Define \033[36mCOMPAT=lex\033[0m to run flex in original lex compatibility mode"
	@echo "- Define \033[36mCOMPAT=posix\033[0m to run flex in POSIX lex compatibility mode"