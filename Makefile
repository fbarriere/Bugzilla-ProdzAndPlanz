
VERSION := 0.0.0
PACKAGE := prodzandplanz
PREFIX  := ProdzAndPlanz

release:
	touch disabled
	tar cvfz ../$(PACKAGE)-$(VERSION).tar.gz . --transform=s,./,$(PREFIX)/, \
		--exclude .git \
		--exclude .project \
		--exclude .gitignore . \
		--exclude Makefile
	rm disabled
