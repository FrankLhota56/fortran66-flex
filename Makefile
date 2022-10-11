PACKAGE ?= fortran66.tgz

f66dump: f66dump.o lex.yy.o get_card.o
	$(CC) -o $@ $^ -L/usr/local/opt/flex/lib -lfl -lm
f66dump.o: f66dump.c field_desc.h fortran66.tab.h

lex.yy.o: lex.yy.c get_card.h fortran66.tab.h
lex.yy.c: fortran66.l
	flex -i $<

get_card.o: get_card.c get_card.h

fortran66.tab.o: fortran66.tab.c field_desc.h fortran66.tab.h
fortran66.tab.h: fortran66.y
	bison -d $<
fortran66.tab.c: fortran66.tab.h

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
	flex -d -i fortran66.l
	$(MAKE) f66dump

.PHONY: clean
clean: ## Removes all generated files.
	$(RM) *.o f66dump fortran66.tab.[hc] lex.yy.c
	$(RM) -r test/actual

.PHONY: package
package: clean	## Packages sources into a gzip tar file.
	tar --create --verbose --gzip --file="$(PACKAGE)" $$(find * -type f \! -name "$(PACKAGE)")


.PHONY: help
help: ## Print out a list of available build targets.
	@echo "Make targets:"
	@echo
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo
